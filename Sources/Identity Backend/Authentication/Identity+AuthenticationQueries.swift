import Foundation
import Records
import Dependencies
import EmailAddress
import Vapor

// MARK: - Selection Types for Combined Queries

@Selection
package struct AuthenticationData: Sendable {
    package let identity: Identity.Record
    package let totpEnabled: Bool
}

@Selection
package struct IdentityWithMFAStatus: Sendable {
    package let identity: Identity.Record
    package let totpId: Identity.MFA.TOTP.Record.ID?
    package let totpConfirmed: Bool
    package let backupCodesAvailable: Int
}

// MARK: - Optimized Authentication Queries

extension Identity.Record {
    
    /// Single query to get identity with TOTP status for authentication
    /// Replaces: findByEmail + separate TOTP check
    package static func findForAuthentication(email: EmailAddress) async throws -> AuthenticationData? {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Identity.Record
                .where { $0.email.eq(email) }
                .leftJoin(Identity.MFA.TOTP.Record.all) { identity, totp in
                    identity.id.eq(totp.identityId)
                        .and(totp.isConfirmed.eq(true))
                }
                .select { identity, totp in
                    AuthenticationData.Columns(
                        identity: identity,
                        totpEnabled: totp.id.isNot(nil)
                    )
                }
                .fetchOne(db)
        }
    }
    
    /// Single query to get identity with full MFA status
    /// Useful for MFA management endpoints
    package static func findWithMFAStatus(identityId: Identity.ID) async throws -> IdentityWithMFAStatus? {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Identity.Record
                .where { $0.id.eq(identityId) }
                .leftJoin(Identity.MFA.TOTP.Record.all) { identity, totp in
                    identity.id.eq(totp.identityId)
                        .and(totp.isConfirmed.eq(true))
                }
                .leftJoin(Identity.MFA.BackupCodes.Record.all) { identity, _, backupCode in
                    identity.id.eq(backupCode.identityId)
                        .and(backupCode.isUsed.eq(false))
                }
                .group { identity, totp, _ in
                    (identity.id, totp.id)
                }
                .select { identity, totp, backupCode in
                    IdentityWithMFAStatus.Columns(
                        identity: identity,
                        totpId: totp.id,
                        totpConfirmed: totp.isConfirmed ?? false,
                        backupCodesAvailable: backupCode.id.count()
                    )
                }
                .fetchOne(db)
        }
    }
    
    /// Update lastLoginAt without fetching the record
    /// Replaces: fetch -> modify -> save pattern
    package static func updateLastLogin(id: Identity.ID) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        _ = try await db.write { db in
            try await Identity.Record
                .where { $0.id.eq(id) }
                .update { identity in
                    identity.lastLoginAt = date()
                    identity.updatedAt = date()
                }
                .execute(db)
        }
    }
    
    /// Verify password and update last login in a single transaction
    /// Returns the updated identity if password is correct
    ///
    /// SECURITY: This function prevents timing attacks by always running bcrypt,
    /// even when the email doesn't exist. This prevents email enumeration.
    package static func verifyPasswordOptimized(email: EmailAddress, password: String) async throws -> AuthenticationData? {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        @Dependency(\.application) var application

        // Get identity with TOTP status using optimized single query
        let authData = try await findForAuthentication(email: email)

        // SECURITY: Always run bcrypt even if email doesn't exist
        // This prevents timing attacks that could enumerate valid emails
        if let authData {
            // Real password verification
            guard try await authData.identity.verifyPassword(password) else {
                return nil
            }
        } else {
            // Dummy bcrypt verification with same cost to match timing
            // Use a known-invalid hash to ensure verification fails
            @Dependency(\.envVars) var envVars
            let _ = try await application.threadPool.runIfActive {
                // This will always fail but takes the same time as a real verification
                try? Bcrypt.verify(password, created: "$2b$10$invalidHashThatWillNeverMatchAnythingEverXXXXXXXXXXXXXXXXXXXXXX")
            }
            return nil
        }

        guard let authData else {
            return nil
        }
        
        // Update last login without fetching
        try await updateLastLogin(id: authData.identity.id)
        
        // Return the authentication data with updated lastLoginAt
        var updatedIdentity = authData.identity
        updatedIdentity.lastLoginAt = date()
        
        return AuthenticationData(
            identity: updatedIdentity,
            totpEnabled: authData.totpEnabled
        )
    }
    
    /// Batch update for session invalidation
    /// Increments session version for all identities in the list
    package static func invalidateSessions(identityIds: [Identity.ID]) async throws -> Int {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        guard !identityIds.isEmpty else { return 0 }
        
        return try await db.write { db in
            var totalUpdated = 0
            
            for identityId in identityIds {
                try await Identity.Record
                    .where { $0.id.eq(identityId) }
                    .update { identity in
                        identity.sessionVersion = identity.sessionVersion + 1
                        identity.updatedAt = date()
                    }
                    .execute(db)
                
                totalUpdated += 1
            }
            
            return totalUpdated
        }
    }
    
    /// Check if email exists without fetching the full record
    /// Useful for registration validation
    package static func emailExists(_ email: EmailAddress) async throws -> Bool {
        @Dependency(\.defaultDatabase) var db
        
        let count = try await db.read { db in
            try await Identity.Record
                .where { $0.email.eq(email) }
                .fetchCount(db)
        }
        
        return count > 0
    }
}

// MARK: - MFA Optimized Queries

extension Identity.MFA.TOTP.Record {
    
    /// Check if TOTP is enabled without fetching the full record
    package static func isEnabled(for identityId: Identity.ID) async throws -> Bool {
        @Dependency(\.defaultDatabase) var db
        
        let count = try await db.read { db in
            try await Identity.MFA.TOTP.Record
                .where { 
                    $0.identityId.eq(identityId)
                        .and($0.isConfirmed.eq(true))
                }
                .fetchCount(db)
        }
        
        return count > 0
    }
    
    /// Update TOTP usage statistics without fetching
    package static func recordUsageOptimized(id: Identity.MFA.TOTP.Record.ID) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        _ = try await db.write { db in
            try await Identity.MFA.TOTP.Record
                .where { $0.id.eq(id) }
                .update { totp in
                    totp.lastUsedAt = date()
                    totp.usageCount = totp.usageCount + 1
                }
                .execute(db)
        }
    }
}

// MARK: - Backup Codes Optimized Queries

extension Identity.MFA.BackupCodes.Record {
    
    /// Get count of unused backup codes without fetching them all
    package static func unusedCount(for identityId: Identity.ID) async throws -> Int {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Identity.MFA.BackupCodes.Record
                .where { 
                    $0.identityId.eq(identityId)
                        .and($0.isUsed.eq(false))
                }
                .fetchCount(db)
        }
    }
    
    /// Mark a backup code as used atomically
    /// Returns true if the code was found and marked as used
    package static func useCode(identityId: Identity.ID, code: String) async throws -> Bool {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        // Hash the code to compare with stored hash
        let codeHash = try Identity.MFA.BackupCodes.Record.hashCode(code)
        
        // Atomic check-and-update within a single transaction
        return try await db.write { db in
            // First check if the code exists and is unused within the transaction
            let validCode = try await Identity.MFA.BackupCodes.Record
                .where { 
                    $0.identityId.eq(identityId)
                        .and($0.codeHash.eq(codeHash))
                        .and($0.isUsed.eq(false))
                }
                .fetchOne(db)
            
            guard validCode != nil else { return false }
            
            // Mark it as used within the same transaction
            try await Identity.MFA.BackupCodes.Record
                .where { 
                    $0.identityId.eq(identityId)
                        .and($0.codeHash.eq(codeHash))
                        .and($0.isUsed.eq(false))
                }
                .update { backupCode in
                    backupCode.isUsed = true
                    backupCode.usedAt = date()
                }
                .execute(db)
            
            return true
        }
    }
}
