//
//  Identity.OAuth.Encryption.swift
//  swift-identities
//
//  Handles OAuth token encryption/decryption following TOTP encryption pattern
//

import Foundation
import Crypto
import Dependencies
import Logging

extension Identity.OAuth {
    /// Handles OAuth token encryption/decryption
    /// Following the established pattern from TOTP secret encryption
    public struct Encryption {
        
        /// Encrypt OAuth token for storage
        /// Returns encrypted token with version prefix, or plain token in development
        public static func encrypt(token: String) throws -> String {
            @Dependency(\.envVars.encryptionKey) var encryptionKey
            @Dependency(\.logger) var logger
            
            // Development mode - no encryption
            guard !encryptionKey.isEmpty else {
                logger.warning("OAuth tokens stored without encryption - set IDENTITIES_ENCRYPTION_KEY in production", metadata: [
                    "component": "Identity.OAuth.Encryption",
                    "mode": "development"
                ])
                return token
            }
            
            // Use proper AES-GCM encryption
            let keyData = SHA256.hash(data: Data(encryptionKey.utf8))
            let key = SymmetricKey(data: keyData)
            let data = Data(token.utf8)
            let sealedBox = try AES.GCM.seal(data, using: key)
            
            // Prefix with "v1:" for version tracking
            return "v1:" + sealedBox.combined!.base64EncodedString()
        }
        
        /// Decrypt OAuth token for use
        /// Handles both encrypted (v1:) and unencrypted tokens
        public static func decrypt(token encrypted: String) throws -> String {
            @Dependency(\.envVars.encryptionKey) var encryptionKey
            @Dependency(\.logger) var logger
            
            // Empty token - nothing to decrypt
            if encrypted.isEmpty {
                return encrypted
            }
            
            // Check if unencrypted (development mode or legacy)
            if encryptionKey.isEmpty {
                if encrypted.hasPrefix("v1:") {
                    logger.error("Found encrypted token but no encryption key set", metadata: [
                        "component": "Identity.OAuth.Encryption"
                    ])
                    throw OAuthTokenError.encryptionKeyMissing
                }
                return encrypted
            }
            
            // Not our encrypted format - return as-is (backward compatibility)
            if !encrypted.hasPrefix("v1:") {
                logger.debug("Token not in encrypted format, returning as-is", metadata: [
                    "component": "Identity.OAuth.Encryption"
                ])
                return encrypted
            }
            
            // Remove version prefix and decrypt
            let encryptedData = String(encrypted.dropFirst(3))
            guard let data = Data(base64Encoded: encryptedData) else {
                logger.error("Failed to decode base64 token data", metadata: [
                    "component": "Identity.OAuth.Encryption"
                ])
                throw OAuthTokenError.invalidTokenFormat
            }
            
            let keyData = SHA256.hash(data: Data(encryptionKey.utf8))
            let key = SymmetricKey(data: keyData)
            
            do {
                let sealedBox = try AES.GCM.SealedBox(combined: data)
                let decrypted = try AES.GCM.open(sealedBox, using: key)
                
                guard let token = String(data: decrypted, encoding: .utf8) else {
                    throw OAuthTokenError.decryptionFailed
                }
                
                return token
            } catch {
                logger.error("Failed to decrypt OAuth token", metadata: [
                    "component": "Identity.OAuth.Encryption",
                    "error": "\(error)"
                ])
                throw OAuthTokenError.decryptionFailed
            }
        }
        
        /// Check if encryption is available
        public static var isEncryptionAvailable: Bool {
            @Dependency(\.envVars.encryptionKey) var encryptionKey
            return !encryptionKey.isEmpty
        }
        
        /// Check if a token is encrypted (has version prefix)
        public static func isEncrypted(_ token: String) -> Bool {
            return token.hasPrefix("v1:")
        }
    }
}

// MARK: - Errors

public enum OAuthTokenError: Error, LocalizedError {
    case encryptionKeyMissing
    case invalidTokenFormat
    case decryptionFailed
    case encryptionRequired
    
    public var errorDescription: String? {
        switch self {
        case .encryptionKeyMissing:
            return "Encryption key not configured but found encrypted token"
        case .invalidTokenFormat:
            return "Invalid OAuth token format"
        case .decryptionFailed:
            return "Failed to decrypt OAuth token"
        case .encryptionRequired:
            return "OAuth provider requires token storage but encryption key not configured"
        }
    }
}
