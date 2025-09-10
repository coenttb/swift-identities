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

extension Identity.Backend.Client.OAuth {
    public static func live(
        registry: OAuthProviderRegistry,
        stateManager: OAuthStateManager
    ) -> Identity.Client.OAuth {
        
        return .init(
            registerProvider: { provider in
                await registry.register(provider)
            },
            
            provider: { identifier in
                await registry.provider(for: identifier)
            },
            
            providers: {
                await registry.allProviders()
            },
            
            authorizationURL: { providerIdentifier, redirectURI in
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
            },
            
            callback: { credentials in
                // 1. Validate state
                let stateData = try await stateManager.validateState(credentials.state)
                
                // 2. Get provider
                guard let provider = await registry.provider(for: credentials.provider) else {
                    throw OAuthError.providerNotFound(credentials.provider)
                }
                
                // 3. Exchange code for tokens
                let tokens = try await provider.exchangeCode(
                    credentials.code,
                    redirectURI: credentials.redirectURI
                )
                
                // 4. Get user info
                let userInfo = try await provider.getUserInfo(
                    accessToken: tokens.accessToken
                )
                
                @Dependency(\.defaultDatabase) var database
                
                // 5. Find or create identity
                let identity: Database.Identity = try await database.write { db in
                    // Check if OAuth connection already exists
                    if let existingConnection = try await Database.OAuthConnection.find(
                        provider: credentials.provider,
                        providerUserId: userInfo.id
                    ) {
                        // Get the associated identity
                        guard let identity = try await Database.Identity.find(existingConnection.identityId).fetchOne(db) else {
                            throw OAuthError.userInfoExtractionFailed
                        }
                        
                        // Update tokens
                        try await existingConnection.updateTokens(
                            accessToken: try Bcrypt.hash(tokens.accessToken),
                            refreshToken: tokens.refreshToken.map { try Bcrypt.hash($0) },
                            expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(Double($0)) }
                        )
                        
                        return identity
                    }
                    
                    // Check if we're linking to an existing identity
                    if let identityId = stateData.identityId {
                        // Linking OAuth to existing account
                        guard let identity = try await Database.Identity.find(identityId).fetchOne(db) else {
                            throw OAuthError.userInfoExtractionFailed
                        }
                        
                        // Create OAuth connection
                        let connection = Database.OAuthConnection(
                            identityId: identityId,
                            provider: credentials.provider,
                            providerUserId: userInfo.id,
                            accessToken: try Bcrypt.hash(tokens.accessToken),
                            refreshToken: try tokens.refreshToken.map { try Bcrypt.hash($0) },
                            tokenType: tokens.tokenType,
                            expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(Double($0)) },
                            scopes: tokens.scope?.components(separatedBy: " "),
                            userInfo: userInfo.rawData
                        )
                        
                        try await Database.OAuthConnection.insert { connection }.execute(db)
                        
                        return identity
                    }
                    
                    // Create new identity from OAuth
                    guard let email = userInfo.email else {
                        throw OAuthError.missingEmail
                    }
                    
                    // Check if email already exists
                    if let existingIdentity = try await Database.Identity.findByEmail(email) {
                        // Link OAuth to existing identity with same email
                        let connection = Database.OAuthConnection(
                            identityId: existingIdentity.id,
                            provider: credentials.provider,
                            providerUserId: userInfo.id,
                            accessToken: try Bcrypt.hash(tokens.accessToken),
                            refreshToken: try tokens.refreshToken.map { try Bcrypt.hash($0) },
                            tokenType: tokens.tokenType,
                            expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(Double($0)) },
                            scopes: tokens.scope?.components(separatedBy: " "),
                            userInfo: userInfo.rawData
                        )
                        
                        try await Database.OAuthConnection.insert { connection }.execute(db)
                    }
                    
                    
                    
                    // Create new identity
                    let newIdentity = try await Database.Identity.init(
                        email: try .init(email),
                        password: "",
                        emailVerificationStatus: userInfo.emailVerified == true ? .verified : .unverified
                    )
                    
                    // Create OAuth connection
                    let connection = Database.OAuthConnection(
                        identityId: newIdentity.id,
                        provider: credentials.provider,
                        providerUserId: userInfo.id,
                        accessToken: try Bcrypt.hash(tokens.accessToken),
                        refreshToken: try tokens.refreshToken.map { try Bcrypt.hash($0) },
                        tokenType: tokens.tokenType,
                        expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(Double($0)) },
                        scopes: tokens.scope?.components(separatedBy: " "),
                        userInfo: userInfo.rawData
                    )
                    
                    try await Database.OAuthConnection.insert { connection }.execute(db)
                    
                    return newIdentity
                }
                
                // 6. Generate authentication tokens
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
            },
            
            connection: { provider in
                // This would need the current identity context
                // Typically called from a protected route with identity in context
                nil // Placeholder - needs request context
            },
            
            disconnect: { provider in
                // This would need the current identity context
                // Typically called from a protected route with identity in context
                // Placeholder - needs request context
            }
        )
    }
}
