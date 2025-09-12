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
import EmailAddress

extension Identity.OAuth.Client {
    public static func live(
        registry: Identity.OAuth.ProviderRegistry,
        stateManager: Identity.OAuth.State.Manager
    ) -> Identity.OAuth.Client {
        
        return .init(
            registerProvider: { await registry.register($0) },
            provider: { await registry.provider(for: $0) },
            providers: { await registry.allProviders() },
            authorizationURL: authorizationURLImplementation(registry: registry, stateManager: stateManager),
            callback: callbackImplementation(registry: registry, stateManager: stateManager),
            connection: connectionImplementation,
            disconnect: disconnectImplementation,
            getValidToken: getValidTokenImplementation(registry: registry),
            getAllConnections: getAllConnectionsImplementation
        )
    }
}

// MARK: - Authorization URL
private func authorizationURLImplementation(
    registry: Identity.OAuth.ProviderRegistry,
    stateManager: Identity.OAuth.State.Manager
) -> @Sendable (String, String) async throws -> URL {
    return { providerIdentifier, redirectURI in
        guard let provider = await registry.provider(for: providerIdentifier) else {
            throw Identity.OAuth.Error.providerNotFound(providerIdentifier)
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
    registry: Identity.OAuth.ProviderRegistry,
    stateManager: Identity.OAuth.State.Manager
) -> @Sendable (Identity.OAuth.CallbackRequest) async throws -> Identity.Authentication.Response {
    return { callbackRequest in
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.logger) var logger
        @Dependency(\.date) var date
        @Dependency(Identity.Token.Client.self) var tokenClient
        
        // 1. Validate state and get provider
        let stateData = try await stateManager.validateState(callbackRequest.state)
        
        guard let provider = await registry.provider(for: callbackRequest.provider) else {
            throw Identity.OAuth.Error.providerNotFound(callbackRequest.provider)
        }
        
        // 2. Exchange code for tokens and get user info (can't avoid these external calls)
        let tokens = try await provider.exchangeCode(
            callbackRequest.code,
            redirectURI: stateData.redirectURI
        )
        
        let userInfo = try await provider.getUserInfo(
            accessToken: tokens.accessToken
        )
        
        // 3. Prepare stored tokens based on provider requirements
        let (storedAccessToken, storedRefreshToken) = try prepareTokensForStorage(
            tokens: tokens,
            provider: provider,
            logger: logger
        )
        
        // 4. Single database transaction for all operations
        let identity = try await database.write { db in
            // First, check for existing OAuth connection
            let existingConnection = try await Identity.OAuth.Connection.Record
                .where { $0.provider.eq(callbackRequest.provider) }
                .where { $0.providerUserId.eq(userInfo.id) }
                .fetchOne(db)
            
            if let existingConnection {
                // Update tokens if needed and return associated identity
                if provider.requiresTokenStorage {
                    let now = date()
                    try await Identity.OAuth.Connection.Record
                        .where { $0.id.eq(existingConnection.id) }
                        .update { connection in
                            connection.accessToken = storedAccessToken
                            if let newRefreshToken = storedRefreshToken {
                                connection.refreshToken = newRefreshToken
                            }
                            connection.expiresAt = tokens.expiresIn.map {
                                Date().addingTimeInterval(Double($0))
                            }
                            connection.lastUsedAt = now
                            connection.updatedAt = now
                        }
                        .execute(db)
                }
                
                guard let identity = try await Identity.Record
                    .where ({ $0.id.eq(existingConnection.identityId) })
                    .fetchOne(db)
                else {
                    throw Identity.OAuth.Error.userInfoExtractionFailed
                }
                
                return identity
            }
            
            // Determine target identity
            let targetIdentity: Identity.Record
            
            if let linkToIdentityId = stateData.identityId {
                // Linking to existing identity (user explicitly requested)
                guard let identity = try await Identity.Record
                    .where ({ $0.id.eq(linkToIdentityId) })
                    .fetchOne(db)
                else {
                    throw Identity.OAuth.Error.userInfoExtractionFailed
                }
                targetIdentity = identity
                
            } else if let email = userInfo.email {
                // Check for existing identity with same email
                if let existingIdentity = try await Identity.Record
                    .where ({ $0.emailString.eq(email) })
                    .fetchOne(db)
                {
                    targetIdentity = existingIdentity
                } else {
                    // Create new identity with RETURNING clause
                    let newIdentityDraft = Identity.Record.Draft(
                        emailString: email,
                        passwordHash: "",  // OAuth users don't have passwords
                        emailVerificationStatus: userInfo.emailVerified == true ? .verified : .unverified,
                        sessionVersion: 0,
                        createdAt: date(),
                        updatedAt: date(),
                        lastLoginAt: date()
                    )
                    
                    // Use RETURNING to get the created identity in one operation
                    let createdIdentity = try await Identity.Record
                        .insert { newIdentityDraft }
                        .returning { $0 }
                        .fetchOne(db)
                    
                    guard let createdIdentity else {
                        throw Identity.OAuth.Error.userInfoExtractionFailed
                    }
                    
                    targetIdentity = createdIdentity
                }
            } else {
                throw Identity.OAuth.Error.missingEmail
            }
            
            // Create OAuth connection for the target identity
            let connection = Identity.OAuth.Connection.Record.Draft(
                identityId: targetIdentity.id,
                provider: callbackRequest.provider,
                userInfo: userInfo,
                tokens: tokens,
                storedAccessToken: storedAccessToken,
                storedRefreshToken: storedRefreshToken
            )
            
            try await Identity.OAuth.Connection.Record
                .insert { connection }
                .execute(db)
            
            return targetIdentity
        }
        
        // 5. Generate authentication tokens
        
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

// MARK: - Helper Functions

/// Prepare OAuth tokens for storage based on provider requirements
private func prepareTokensForStorage(
    tokens: Identity.OAuth.TokenResponse,
    provider: Identity.OAuth.Provider,
    logger: Logger
) throws -> (accessToken: String, refreshToken: String?) {
    if provider.requiresTokenStorage {
        guard Identity.OAuth.Encryption.isEncryptionAvailable else {
            logger.error("OAuth provider requires token storage but IDENTITIES_ENCRYPTION_KEY not set",
                         metadata: ["provider": "\(provider.identifier)"])
            throw OAuthTokenError.encryptionRequired
        }
        
        let storedAccessToken = try Identity.OAuth.Encryption.encrypt(token: tokens.accessToken)
        let storedRefreshToken = try tokens.refreshToken.map {
            try Identity.OAuth.Encryption.encrypt(token: $0)
        }
        
        logger.debug("OAuth tokens encrypted for storage",
                     metadata: ["provider": "\(provider.identifier)"])
        
        return (storedAccessToken, storedRefreshToken)
    } else {
        logger.debug("OAuth used for authentication only, tokens not stored",
                     metadata: ["provider": "\(provider.identifier)"])
        return ("", nil)
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
        throw Identity.OAuth.Error.providerNotFound(provider)
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
    registry: Identity.OAuth.ProviderRegistry
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
                return try Identity.OAuth.Encryption.decrypt(token: connection.accessToken)
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
                return try Identity.OAuth.Encryption.decrypt(token: connection.accessToken)
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
            
            throw Identity.OAuth.Error.tokenExpired
        }
        
        guard let refreshToken = connection.refreshToken else {
            logger.error("Token expired but no refresh token available", metadata: [
                "provider": "\(providerName)"
            ])
            throw Identity.OAuth.Error.tokenExpired
        }
        
        do {
            // Decrypt refresh token
            let decryptedRefresh = try Identity.OAuth.Encryption.decrypt(token: refreshToken)
            
            // Call provider to refresh
            guard let newTokens = try await provider.refreshToken(decryptedRefresh) else {
                logger.error("Provider refresh returned nil", metadata: [
                    "provider": "\(providerName)"
                ])
                throw Identity.OAuth.Error.tokenExchangeFailed
            }
            
            // Update stored tokens
            let newAccessToken = try Identity.OAuth.Encryption.encrypt(token: newTokens.accessToken)
            let newRefreshToken = try newTokens.refreshToken.map {
                try Identity.OAuth.Encryption.encrypt(token: $0)
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

extension Identity.OAuth.Connection.Record.Draft {
    /// Convenience initializer that creates a Draft from OAuth response objects
    /// Extracts common patterns like expiration calculation and scope parsing
    init(
        identityId: Identity.ID,
        provider: String,
        userInfo: Identity.OAuth.UserInfo,
        tokens: Identity.OAuth.TokenResponse,
        storedAccessToken: String,
        storedRefreshToken: String?
    ) {
        @Dependency(\.date) var date
        let now = date()
        
        self.init(
            identityId: identityId,
            provider: provider,
            providerUserId: userInfo.id,
            accessToken: storedAccessToken,
            refreshToken: storedRefreshToken,
            tokenType: tokens.tokenType,
            expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(Double($0)) },
            scopes: tokens.scope?.components(separatedBy: " "),
            userInfo: userInfo.rawData,
            createdAt: now,
            updatedAt: now,
            lastUsedAt: now
        )
    }
}
