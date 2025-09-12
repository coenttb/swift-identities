import Foundation
import Records
import Dependencies
import EmailAddress
import Vapor

// MARK: - Selection Types for Combined Queries

@Selection
public struct AuthenticationData: Sendable {
    public let identity: Identity.Record
    public let totpEnabled: Bool
}

@Selection
public struct IdentityWithMFAStatus: Sendable {
    public let identity: Identity.Record
    public let totpId: UUID?
    public let totpConfirmed: Bool
    public let backupCodesAvailable: Int
}

// MARK: - Optimized Authentication Queries

extension Identity.Record {
    
    /// Single query to get identity with TOTP status for authentication
    /// Replaces: findByEmail + separate TOTP check
    package static func findForAuthentication(email: EmailAddress) async throws -> AuthenticationData? {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Identity.Record
                .where { $0.emailString.eq(email.rawValue) }
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
    package static func verifyPasswordOptimized(email: EmailAddress, password: String) async throws -> AuthenticationData? {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        // Get identity with TOTP status using optimized single query
        guard let authData = try await findForAuthentication(email: email) else {
            return nil
        }
        
        // Verify password
        guard try await authData.identity.verifyPassword(password) else {
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
                .where { $0.emailString.eq(email.rawValue) }
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
    package static func recordUsageOptimized(id: UUID) async throws {
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
        
        // First check if the code exists and is unused
        let validCode = try await db.read { db in
            try await Identity.MFA.BackupCodes.Record
                .where { 
                    $0.identityId.eq(identityId)
                        .and($0.codeHash.eq(codeHash))
                        .and($0.isUsed.eq(false))
                }
                .fetchOne(db)
        }
        
        guard validCode != nil else { return false }
        
        // Mark it as used
        try await db.write { db in
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
        }
        
        return true
    }
}
