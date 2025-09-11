import Foundation
import Records
import Dependencies
import Vapor
import Crypto
import TOTP
import RFC_6238

// MARK: - Database Operations

extension Identity.MFA.TOTP.Record {
    
    package static func findByIdentity(_ identityId: Identity.ID) async throws -> Identity.MFA.TOTP.Record? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Identity.MFA.TOTP.Record.findByIdentity(identityId)
                .fetchOne(db)
        }
    }
    
    package static func findConfirmedByIdentity(_ identityId: Identity.ID) async throws -> Identity.MFA.TOTP.Record? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Identity.MFA.TOTP.Record.findConfirmedByIdentity(identityId)
                .fetchOne(db)
        }
    }
    
    package static func create(
        identityId: Identity.ID,
        secret: String,
        algorithm: RFC_6238.TOTP.Algorithm = .sha1,
        digits: Int = 6,
        timeStep: Int = 30
    ) async throws -> Identity.MFA.TOTP.Record {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        
        let totp = Identity.MFA.TOTP.Record(
            id: uuid(),
            identityId: identityId,
            secret: secret,
            isConfirmed: false,
            algorithm: algorithm,
            digits: digits,
            timeStep: timeStep
        )
        
        _ = try await db.write { db in
            try await Identity.MFA.TOTP.Record.insert { totp }
                .execute(db)
        }
        
        return totp
    }
    
    package func confirm() async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.logger) var logger
        
        _ = try await db.write { db in
            try await Identity.MFA.TOTP.Record
                .update { totp in
                    totp.isConfirmed = true
                    totp.confirmedAt = Date()
                }
                .where { $0.id.eq(self.id) }
                .execute(db)
        }
    }
    
    package func recordUsage() async throws {
        @Dependency(\.defaultDatabase) var db
        
        let now = Date()
        _ = try await db.write { db in
            try await Identity.MFA.TOTP.Record
                .update { totp in
                    totp.lastUsedAt = now
                    totp.usageCount = totp.usageCount + 1
                }
                .where { $0.id.eq(self.id) }
                .execute(db)
        }
    }
    
    package static func deleteForIdentity(_ identityId: Identity.ID) async throws {
        @Dependency(\.defaultDatabase) var db
        _ = try await db.write { db in
            try await Identity.MFA.TOTP.Record
                .delete()
                .where { $0.identityId.eq(identityId) }
                .execute(db)
        }
    }
}

// MARK: - Helper Functions

extension Identity.MFA.TOTP.Record {
    /// Encrypt the secret for storage
    package static func encryptSecret(_ secret: String) throws -> String {
        @Dependency(\.envVars.encryptionKey) var encryptionKey
        @Dependency(\.logger) var logger
        
        // If no encryption key is set, store as-is (development mode)
        guard !encryptionKey.isEmpty else {
            logger.warning("TOTP secrets stored without encryption - set IDENTITIES_ENCRYPTION_KEY in production")
            return secret
        }
        
        // For now, we'll use a simple Base64 encoding of the key+secret
        // In production, use proper AES encryption with the key
        let combined = "\(encryptionKey):\(secret)"
        return Data(combined.utf8).base64EncodedString()
    }
    
    /// Decrypt the secret for use
    package func decryptedSecret() throws -> String {
        @Dependency(\.envVars.encryptionKey) var encryptionKey
        @Dependency(\.logger) var logger
        
        // Check if this might be an encrypted secret
        if !encryptionKey.isEmpty {
            // Try to decode as encrypted Base64
            if let data = Data(base64Encoded: self.secret),
               let decoded = String(data: data, encoding: .utf8) {
                // Check if it has our encryption prefix
                if decoded.hasPrefix("\(encryptionKey):") {
                    // Extract the actual secret after the key prefix
                    return String(decoded.dropFirst(encryptionKey.count + 1))
                }
            }
        }
        
        // Handle legacy migration from old Base64-encoded secrets
        // Base32 only uses: A-Z, 2-7, =
        // Base64 uses: A-Z, a-z, 0-9, +, /, =
        let base32Charset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=")
        let secretCharset = CharacterSet(charactersIn: self.secret)
        
        if !secretCharset.isSubset(of: base32Charset) {
            // Contains characters not in Base32, likely legacy Base64-encoded
            if let data = Data(base64Encoded: self.secret),
               let decodedSecret = String(data: data, encoding: .utf8) {
                // Check it's not our new encrypted format
                if !encryptionKey.isEmpty && decodedSecret.hasPrefix("\(encryptionKey):") {
                    return String(decodedSecret.dropFirst(encryptionKey.count + 1))
                }
                return decodedSecret
            }
            logger.warning("Failed to decode Base64-encoded TOTP secret")
        }
        
        // Plain Base32 secret (unencrypted)
        return self.secret
    }
    
    enum TOTPError: Swift.Error {
        case invalidSecret
        case alreadyExists
    }
}
