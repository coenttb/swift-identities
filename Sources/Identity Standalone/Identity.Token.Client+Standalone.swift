//
//  Identity.Token.Client+Standalone.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 18/08/2025.
//

import Foundation
import Dependencies
import IdentitiesTypes
import Identity_Shared
import Identity_Backend
import ServerFoundation
import JWT
import Crypto
import Records

extension Identity.Token.Client: DependencyKey {
    /// Default JWT token client configuration for Standalone deployments.
    /// Enriches tokens with displayName when available.
    public static var liveValue: Self {
        @Dependency(\.envVars) var envVars
        
        // Get the base configuration
        let configuration = Configuration(
            issuer: envVars.identitiesIssuer,
            audience: envVars.identitiesAudience,
            secretKey: envVars.encryptionKey,
            accessTokenExpiry: envVars.identitiesJWTAccessExpiry,
            refreshTokenExpiry: envVars.identitiesJWTRefreshExpiry,
            reauthorizationTokenExpiry: envVars.identitiesJWTReauthorizationExpiry
        )
        
        return standaloneClient(configuration: configuration)
    }
}

extension Identity.Token.Client {
    /// Development configuration using the unified approach from Backend
    /// Automatically uses environment variables when available
    public static var development: Self {
        let configuration = StandaloneConfiguration.development()
        // Return the base client as-is for now, since we can't easily wrap it
        return configuration
    }
    
    /// Test configuration with very short expiry times
    public static var test: Self {
        Identity.Token.Client.test()
    }
    
    /// Creates a Standalone-specific token client that enriches tokens with profile data
    private static func standaloneClient(configuration: Configuration) -> Self {
        let signingKey = SigningKey(configuration.secretKey.data(using: .utf8)!)
        let verificationKey = VerificationKey(configuration.secretKey.data(using: .utf8)!)
        
        return Self(
            generateAccess: { identityId, email, sessionVersion in
                // For Standalone, try to fetch the profile to add displayName
                @Dependency(\.defaultDatabase) var database
                
                var additionalClaims: [String: Any] = [:]
                
                // Try to fetch the profile's displayName (but don't fail if not found)
                if let profile = try? await database.read { db in
                    try await Identity.Profile.Record.findByIdentity(identityId).fetchOne(db)
                },
                   let displayName = profile.displayName {
                    additionalClaims["displayName"] = displayName
                }
                
                // Generate token with additional claims
                let token = try Identity.Token.Access(
                    identityId: identityId,
                    email: email,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.accessTokenExpiry,
                    signingKey: signingKey,
                    additionalClaims: additionalClaims
                )
                return try token.token
            },
            
            verifyAccess: { tokenString in
                let jwt = try JWT.parse(from: tokenString)
                let token = try Identity.Token.Access(jwt: jwt)
                guard try token.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                return token
            },
            
            generateRefresh: { identityId, sessionVersion in
                let token = try Identity.Token.Refresh(
                    identityId: identityId,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.refreshTokenExpiry,
                    signingKey: signingKey
                )
                return try token.token
            },
            
            verifyRefresh: { tokenString in
                let jwt = try JWT.parse(from: tokenString)
                let token = try Identity.Token.Refresh(jwt: jwt)
                guard try token.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                return token
            },
            
            refreshAccess: { refreshTokenString, identityId, email, sessionVersion in
                // Verify the refresh token first
                let jwt = try JWT.parse(from: refreshTokenString)
                let refreshToken = try Identity.Token.Refresh(jwt: jwt)
                
                guard try refreshToken.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                
                guard refreshToken.isValid else {
                    throw ClientError.tokenExpired
                }
                
                guard refreshToken.identityId == identityId else {
                    throw ClientError.invalidTokenClaims
                }
                
                guard refreshToken.sessionVersion == sessionVersion else {
                    throw ClientError.sessionVersionMismatch
                }
                
                // For refresh, also try to add displayName
                @Dependency(\.defaultDatabase) var database
                
                var additionalClaims: [String: Any] = [:]
                
                // Try to fetch the profile's displayName
                if let profile = try? await database.read { db in
                    try await Identity.Profile.Record.findByIdentity(identityId).fetchOne(db)
                },
                   let displayName = profile.displayName {
                    additionalClaims["displayName"] = displayName
                }
                
                // Generate new access token with additional claims
                let newToken = try Identity.Token.Access(
                    identityId: identityId,
                    email: email,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.accessTokenExpiry,
                    signingKey: signingKey,
                    additionalClaims: additionalClaims
                )
                return try newToken.token
            },
            
            generateMFASession: { identityId, sessionVersion, attemptsRemaining, availableMethods in
                let token = try Identity.Token.MFASession(
                    identityId: identityId,
                    sessionVersion: sessionVersion,
                    attemptsRemaining: attemptsRemaining,
                    availableMethods: availableMethods,
                    issuer: configuration.issuer,
                    expiresIn: 300, // 5 minutes for MFA
                    signingKey: signingKey
                )
                return try token.token
            },
            
            verifyMFASession: { tokenString in
                let jwt = try JWT.parse(from: tokenString)
                let token = try Identity.Token.MFASession(jwt: jwt)
                guard try token.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                return token
            },
            
            generateReauthorization: { identityId, sessionVersion, purpose, allowedOperations in
                let token = try Identity.Token.Reauthorization(
                    identityId: identityId,
                    sessionVersion: sessionVersion,
                    purpose: purpose,
                    allowedOperations: allowedOperations,
                    issuer: configuration.issuer,
                    expiresIn: configuration.reauthorizationTokenExpiry,
                    signingKey: signingKey
                )
                return try token.token
            },
            
            verifyReauthorization: { tokenString in
                let jwt = try JWT.parse(from: tokenString)
                let token = try Identity.Token.Reauthorization(jwt: jwt)
                guard try token.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                return token
            },
            
            generateTokenPair: { identityId, email, sessionVersion in
                // For token pairs, also try to add displayName
                @Dependency(\.defaultDatabase) var database
                
                var additionalClaims: [String: Any] = [:]
                
                // Try to fetch the profile's displayName
                if let profile = try? await database.read ({ db in
                    try await Identity.Profile.Record.findByIdentity(identityId).fetchOne(db)
                }),
                   let displayName = profile.displayName {
                    additionalClaims["displayName"] = displayName
                }
                
                let accessToken = try Identity.Token.Access(
                    identityId: identityId,
                    email: email,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.accessTokenExpiry,
                    signingKey: signingKey,
                    additionalClaims: additionalClaims
                )
                
                let refreshToken = try Identity.Token.Refresh(
                    identityId: identityId,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.refreshTokenExpiry,
                    signingKey: signingKey
                )
                
                return (try accessToken.token, try refreshToken.token)
            },
            
            identifyTokenType: { tokenString in
                guard let jwt = try? JWT.parse(from: tokenString),
                      let type = jwt.payload.additionalClaim("type", as: String.self) else {
                    return .unknown
                }
                
                switch type {
                case "access": return .access
                case "refresh": return .refresh
                case "reauthorization": return .reauthorization
                default: return .unknown
                }
            },
            
            isExpired: { tokenString in
                guard let jwt = try? JWT.parse(from: tokenString),
                      let exp = jwt.payload.exp else {
                    return true
                }
                return Date() > exp
            }
        )
    }
}
