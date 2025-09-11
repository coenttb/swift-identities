//
//  Identity.Backend.Client.OAuth.live.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2025.
//

import Foundation
import Dependencies
import IdentitiesTypes
import Records
import ServerFoundation
import ServerFoundationVapor
import JWT
import Logging

extension Identity.OAuth.Client {
    public static func live(
        registry: OAuthProviderRegistry,
        stateManager: OAuthStateManager
    ) -> Identity.OAuth.Client {
        
        return .init(
            registerProvider: registerProviderImplementation(registry: registry),
            provider: providerImplementation(registry: registry),
            providers: providersImplementation(registry: registry),
            authorizationURL: authorizationURLImplementation(registry: registry, stateManager: stateManager),
            callback: callbackImplementation(registry: registry, stateManager: stateManager),
            connection: connectionImplementation,
            disconnect: disconnectImplementation,
            getValidToken: getValidTokenImplementation(registry: registry),
            getAllConnections: getAllConnectionsImplementation
        )
    }
}

// MARK: - Register Provider
private func registerProviderImplementation(
    registry: OAuthProviderRegistry
) -> @Sendable (Identity.OAuth.Provider) async -> Void {
    return { provider in
        await registry.register(provider)
    }
}

// MARK: - Get Provider
private func providerImplementation(
    registry: OAuthProviderRegistry
) -> @Sendable (String) async -> Identity.OAuth.Provider? {
    return { identifier in
        await registry.provider(for: identifier)
    }
}

// MARK: - Get All Providers
private func providersImplementation(
    registry: OAuthProviderRegistry
) -> @Sendable () async -> [Identity.OAuth.Provider] {
    return {
        await registry.allProviders()
    }
}

// MARK: - Authorization URL
private func authorizationURLImplementation(
    registry: OAuthProviderRegistry,
    stateManager: OAuthStateManager
) -> @Sendable (String, String) async throws -> URL {
    return { providerIdentifier, redirectURI in
        guard let provider = await registry.provider(for: providerIdentifier) else {
            throw OAuthError.providerNotFound(providerIdentifier)
        }
        
        let state = try await stateManager.generateState(
            for: providerIdentifier,
            redirectURI: redirectURI
        )
        
        return try await provider.authorizationURL(
            state: state,
            redirectURI: redirectURI
        )
    }
}

// MARK: - OAuth Callback
private func callbackImplementation(
    registry: OAuthProviderRegistry,
    stateManager: OAuthStateManager
) -> @Sendable (Identity.OAuth.CallbackRequest) async throws -> Identity.Authentication.Response {
    return { callbackRequest in
        // 1. Validate state
        let stateData = try await stateManager.validateState(callbackRequest.state)
        
        // 2. Get provider
        guard let provider = await registry.provider(for: callbackRequest.provider) else {
            throw OAuthError.providerNotFound(callbackRequest.provider)
        }
        
        // 3. Create internal token exchange request with redirectURI from state
        let tokenExchangeRequest = Identity.OAuth.TokenExchangeRequest(
            provider: callbackRequest.provider,
            code: callbackRequest.code,
            redirectURI: stateData.redirectURI
        )
        
        // 4. Exchange code for tokens using redirectURI from state
        let tokens = try await provider.exchangeCode(
            tokenExchangeRequest.code,
            redirectURI: tokenExchangeRequest.redirectURI
        )
        
        // 5. Get user info
        let userInfo = try await provider.getUserInfo(
            accessToken: tokens.accessToken
        )
        
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.logger) var logger
        
        // Determine token storage strategy based on provider configuration
        let storedAccessToken: String
        let storedRefreshToken: String?
        
        if provider.requiresTokenStorage {
            // Provider requires token storage for API access
            if Identity.Backend.OAuthTokenEncryption.isEncryptionAvailable {
                // Encrypt tokens for storage
                storedAccessToken = try Identity.Backend.OAuthTokenEncryption.encryptToken(tokens.accessToken)
                storedRefreshToken = try tokens.refreshToken.map {
                    try Identity.Backend.OAuthTokenEncryption.encryptToken($0)
                }
                logger.debug("OAuth tokens encrypted for storage", metadata: [
                    "provider": "\(provider.identifier)"
                ])
            } else {
                // Provider requires tokens but no encryption key configured
                logger.error("OAuth provider requires token storage but IDENTITIES_ENCRYPTION_KEY not set", metadata: [
                    "provider": "\(provider.identifier)"
                ])
                throw OAuthTokenError.encryptionRequired
            }
        } else {
            // Authentication only - don't store tokens
            storedAccessToken = ""
            storedRefreshToken = nil
            logger.debug("OAuth used for authentication only, tokens not stored", metadata: [
                "provider": "\(provider.identifier)"
            ])
        }
        
        // 6. Find or create identity
        let identity: Identity.Record = try await database.write { db in
            // Check if OAuth connection already exists
            if let existingConnection = try await Identity.OAuth.Connection.Record.find(
                provider: callbackRequest.provider,
                providerUserId: userInfo.id
            ) {
                // Get the associated identity
                guard let identity = try await Identity.Record.find(existingConnection.identityId).fetchOne(db) else {
                    throw OAuthError.userInfoExtractionFailed
                }
                
                // Update tokens if provider stores them
                if provider.requiresTokenStorage {
                    try await existingConnection.updateTokens(
                        accessToken: storedAccessToken,
                        refreshToken: storedRefreshToken,
                        expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(Double($0)) }
                    )
                }
                
                return identity
            }
            
            // Check if we're linking to an existing identity
            if let identityId = stateData.identityId {
                // Linking OAuth to existing account
                guard let identity = try await Identity.Record.find(identityId).fetchOne(db) else {
                    throw OAuthError.userInfoExtractionFailed
                }
                
                // Create OAuth connection
                let connection = Identity.OAuth.Connection.Record(
                    identityId: identityId,
                    provider: callbackRequest.provider,
                    providerUserId: userInfo.id,
                    accessToken: storedAccessToken,
                    refreshToken: storedRefreshToken,
                    tokenType: tokens.tokenType,
                    expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(Double($0)) },
                    scopes: tokens.scope?.components(separatedBy: " "),
                    userInfo: userInfo.rawData
                )
                
                try await Identity.OAuth.Connection.Record.insert { connection }.execute(db)
                
                return identity
            }
            
            // Create new identity from OAuth
            guard let email = userInfo.email else {
                throw OAuthError.missingEmail
            }
            
            // Check if email already exists
            if let existingIdentity = try await Identity.Record.findByEmail(email) {
                // Link OAuth to existing identity with same email
                let connection = Identity.OAuth.Connection.Record(
                    identityId: existingIdentity.id,
                    provider: callbackRequest.provider,
                    providerUserId: userInfo.id,
                    accessToken: storedAccessToken,
                    refreshToken: storedRefreshToken,
                    tokenType: tokens.tokenType,
                    expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(Double($0)) },
                    scopes: tokens.scope?.components(separatedBy: " "),
                    userInfo: userInfo.rawData
                )
                
                try await Identity.OAuth.Connection.Record.insert { connection }.execute(db)
                return existingIdentity
            }
            
            // Create new identity
            let newIdentity = try await Identity.Record.init(
                email: try .init(email),
                password: "",
                emailVerificationStatus: userInfo.emailVerified == true ? .verified : .unverified
            )
            
            // Create OAuth connection
            let connection = Identity.OAuth.Connection.Record(
                identityId: newIdentity.id,
                provider: callbackRequest.provider,
                providerUserId: userInfo.id,
                accessToken: storedAccessToken,
                refreshToken: storedRefreshToken,
                tokenType: tokens.tokenType,
                expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(Double($0)) },
                scopes: tokens.scope?.components(separatedBy: " "),
                userInfo: userInfo.rawData
            )
            
            try await Identity.OAuth.Connection.Record.insert { connection }.execute(db)
            
            return newIdentity
        }
        
        // 7. Generate authentication tokens
        @Dependency(Identity.Token.Client.self) var tokenClient
        
        let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
            identity.id,
            identity.email,
            identity.sessionVersion
        )
        
        return Identity.Authentication.Response(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}

// MARK: - Get Connection
private let connectionImplementation: @Sendable (String) async throws -> Identity.OAuth.Connection? = { provider in
    // Get current authenticated identity
    @Dependency(\.defaultDatabase) var database
    
    do {
        let identity = try await Identity.Record.get(by: .auth)
        
        // Find connection for this provider
        guard let dbConnection = try await Identity.OAuth.Connection.Record.find(
            identityId: identity.id,
            provider: provider
        ) else {
            return nil
        }
        
        return Identity.OAuth.Connection(from: dbConnection)
    } catch {
        // Not authenticated or no connection found
        return nil
    }
}

// MARK: - Disconnect Provider
private let disconnectImplementation: @Sendable (String) async throws -> Void = { provider in
    // Get current authenticated identity
    @Dependency(\.defaultDatabase) var database
    
    let identity = try await Identity.Record.get(by: .auth)
    
    // Find and delete the connection
    guard let connection = try await Identity.OAuth.Connection.Record.find(
        identityId: identity.id,
        provider: provider
    ) else {
        throw OAuthError.providerNotFound(provider)
    }
    
    try await database.write { db in
        try await Identity.OAuth.Connection.Record.all
            .where { $0.id.eq(connection.id) }
            .delete()
            .execute(db)
    }
}

// MARK: - Get Valid Token
private func getValidTokenImplementation(
    registry: OAuthProviderRegistry
) -> @Sendable (String) async throws -> String? {
    return { providerName in
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.logger) var logger
        
        let identity = try await Identity.Record.get(by: .auth)
        
        guard let connection = try await Identity.OAuth.Connection.Record.find(
            identityId: identity.id,
            provider: providerName
        ) else {
            return nil
        }
        
        // Get provider
        guard let provider = await registry.provider(for: providerName) else {
            logger.warning("OAuth provider not registered", metadata: [
                "provider": "\(providerName)"
            ])
            return nil
        }
        
        // Check if provider stores tokens
        guard provider.requiresTokenStorage else {
            logger.debug("Provider doesn't store tokens for API access", metadata: [
                "provider": "\(providerName)"
            ])
            return nil
        }

        guard !connection.accessToken.isEmpty else {
            logger.debug("No access token stored for provider", metadata: [
                "provider": "\(providerName)"
            ])
            return nil
        }
        
        // Check if token is still valid
        guard
            let expiresAt = connection.expiresAt
        else {
            do {
                return try Identity.Backend.OAuthTokenEncryption.decryptToken(connection.accessToken)
            } catch {
                logger.error("Failed to decrypt OAuth token", metadata: [
                    "provider": "\(providerName)",
                    "error": "\(error)"
                ])
                throw error
            }
        }

        // Token has expiration date, check if expired
        guard Date() > expiresAt else {
            // Token not expired, return it
            do {
                return try Identity.Backend.OAuthTokenEncryption.decryptToken(connection.accessToken)
            } catch {
                logger.error("Failed to decrypt OAuth token", metadata: [
                    "provider": "\(providerName)",
                    "error": "\(error)"
                ])
                throw error
            }
        }
        
        // Token is expired, attempt refresh
        logger.info("OAuth token expired, attempting refresh", metadata: [
            "provider": "\(providerName)",
            "expiredAt": "\(expiresAt)"
        ])
        
        guard provider.supportsRefresh else {
            logger.error("Token expired but provider doesn't support refresh", metadata: [
                "provider": "\(providerName)"
            ])
            
            throw OAuthError.tokenExpired
        }
        
        guard let refreshToken = connection.refreshToken else {
            logger.error("Token expired but no refresh token available", metadata: [
                "provider": "\(providerName)"
            ])
            throw OAuthError.tokenExpired
        }
        
        do {
            // Decrypt refresh token
            let decryptedRefresh = try Identity.Backend.OAuthTokenEncryption.decryptToken(refreshToken)
            
            // Call provider to refresh
            guard let newTokens = try await provider.refreshToken(decryptedRefresh) else {
                logger.error("Provider refresh returned nil", metadata: [
                    "provider": "\(providerName)"
                ])
                throw OAuthError.tokenExchangeFailed
            }
            
            // Update stored tokens
            let newAccessToken = try Identity.Backend.OAuthTokenEncryption.encryptToken(newTokens.accessToken)
            let newRefreshToken = try newTokens.refreshToken.map {
                try Identity.Backend.OAuthTokenEncryption.encryptToken($0)
            }
            
            try await connection.updateTokens(
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
                expiresAt: newTokens.expiresIn.map { 
                    Date().addingTimeInterval(Double($0)) 
                }
            )
            
            logger.info("OAuth token refreshed successfully", metadata: [
                "provider": "\(providerName)"
            ])
            
            return newTokens.accessToken
        } catch {
            logger.error("Failed to refresh OAuth token", metadata: [
                "provider": "\(providerName)",
                "error": "\(error)"
            ])
            throw error
        }
    }
}

// MARK: - Get All Connections
private let getAllConnectionsImplementation: @Sendable () async throws -> [Identity.OAuth.Connection] = {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.logger) var logger
    
    do {
        let identity = try await Identity.Record.get(by: .auth)
        
        let dbConnections = try await Identity.OAuth.Connection.Record.findAll(
            identityId: identity.id
        )
        
        return dbConnections.map { dbConnection in
            Identity.OAuth.Connection(from: dbConnection)
        }
    } catch {
        logger.error("Failed to get OAuth connections", metadata: [
            "error": "\(error)"
        ])
        return []
    }
}
