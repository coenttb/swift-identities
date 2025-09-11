//
//  Identity.Token.Client+Configuration.swift
//  coenttb-identities
//
//  Unified JWT configuration for all deployment models
//

import Foundation
import Dependencies
import IdentitiesTypes
import Identity_Shared
import ServerFoundation

extension Identity.Token.Client {
    
    /// Production configuration with strict requirements
    public static func live() -> Self {
        @Dependency(\.envVars) var envVars
        
        // Production MUST have JWT_SECRET set
        let secretKey = envVars.encryptionKey
        
        let configuration = Configuration(
            issuer: envVars.identitiesIssuer,
            audience: envVars.identitiesAudience,
            secretKey: secretKey,
            accessTokenExpiry: envVars.identitiesJWTAccessExpiry,
            refreshTokenExpiry: envVars.identitiesJWTRefreshExpiry,
            reauthorizationTokenExpiry: envVars.identitiesJWTReauthorizationExpiry
        )
        
        return .live(configuration: configuration)
    }
    
    /// Development configuration with sensible defaults
    /// Allows overriding via environment variables but provides defaults
    public static func development(
        issuer: String? = nil,
        audience: String? = nil,
        secretKey: String? = nil
    ) -> Self {
        @Dependency(\.envVars) var envVars
        
        let configuration = Configuration(
            issuer: issuer ?? envVars.identitiesIssuer,
            audience: audience ?? envVars.identitiesAudience,
            secretKey: secretKey ?? envVars.encryptionKey,
            accessTokenExpiry: envVars.identitiesJWTAccessExpiry,
            refreshTokenExpiry: envVars.identitiesJWTRefreshExpiry,
            reauthorizationTokenExpiry: envVars.identitiesJWTReauthorizationExpiry
        )
        
        return .live(configuration: configuration)
    }
    
    /// Test configuration with very short expiry times
    public static func test(
        issuer: String = "identity-test",
        audience: String? = nil,
        secretKey: String = "test-secret-key-min-32-bytes-long-for-testing"
    ) -> Self {
        let configuration = Configuration(
            issuer: issuer,
            audience: audience,
            secretKey: secretKey,
            accessTokenExpiry: 10, // 10 seconds for fast testing
            refreshTokenExpiry: 60, // 1 minute
            reauthorizationTokenExpiry: 5 // 5 seconds
        )
        
        return .live(configuration: configuration)
    }
}

// MARK: - Specialized Configurations

extension Identity.Token.Client {
    
    /// Configuration for Provider (API-only) deployments
    /// More strict security requirements than Standalone
    public struct ProviderConfiguration {
        
        public static func production() -> Identity.Token.Client {
            @Dependency(\.envVars) var envVars
            
            // Provider must have JWT_SECRET set
            let secretKey = envVars.encryptionKey
            
            let issuer = envVars.identitiesIssuer
            
            let configuration = Configuration(
                issuer: issuer,
                audience: envVars.identitiesAudience, // Often the API URL
                secretKey: secretKey,
                accessTokenExpiry: envVars.identitiesJWTAccessExpiry,
                refreshTokenExpiry: envVars.identitiesJWTRefreshExpiry,
                reauthorizationTokenExpiry: envVars.identitiesJWTReauthorizationExpiry
            )
            
            return .live(configuration: configuration)
        }
        
        public static func development() -> Identity.Token.Client {
            Identity.Token.Client.development(
                issuer: "identity-provider-dev"
            )
        }
    }
    
    /// Configuration for Standalone deployments
    /// More relaxed for web sessions
    public struct StandaloneConfiguration {
        
        public static func live() -> Identity.Token.Client {
            Identity.Token.Client.live()
        }
        
        public static func development() -> Identity.Token.Client {
            Identity.Token.Client.development(
                issuer: "identity-standalone-dev"
            )
        }
    }
}
