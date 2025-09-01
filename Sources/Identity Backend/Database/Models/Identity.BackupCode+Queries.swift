import Foundation
import Records
import Dependencies
import Vapor
import Crypto

// MARK: - Database Operations

extension Database.Identity.BackupCode {
    
    package static func findById(_ id: UUID) async throws -> Database.Identity.BackupCode? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.BackupCode
                .where { $0.id.eq(id) }
                .fetchOne(db)
        }
    }
    
    package static func findUnusedByIdentity(_ identityId: UUID) async throws -> [Database.Identity.BackupCode] {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.BackupCode.findUnusedByIdentity(identityId)
                .fetchAll(db)
        }
    }
    
    package static func countUnusedByIdentity(_ identityId: UUID) async throws -> Int {
        @Dependency(\.defaultDatabase) var db
        let codes = try await db.read { db in
            try await Database.Identity.BackupCode.findUnusedByIdentity(identityId)
                .fetchAll(db)
        }
        return codes.count
    }
    
    package static func create(
        identityId: UUID,
        codes: [String]
    ) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        
        try await db.write { db in
            // Delete existing unused codes first
            _ = try await Database.Identity.BackupCode
                .delete()
                .where { $0.identityId.eq(identityId) }
                .execute(db)
            
            // Create new backup codes
            for code in codes {
                let backupCode = Database.Identity.BackupCode(
                    id: uuid(),
                    identityId: identityId,
                    codeHash: try hashCode(code)
                )
                
                _ = try await Database.Identity.BackupCode.insert { backupCode }
                    .execute(db)
            }
        }
    }
    
    package static func verify(
        identityId: UUID,
        code: String
    ) async throws -> Bool {
        let unusedCodes = try await findUnusedByIdentity(identityId)
        
        for backupCode in unusedCodes {
            if try verifyCode(code, hash: backupCode.codeHash) {
                // Mark as used
                try await backupCode.markAsUsed()
                return true
            }
        }
        
        return false
    }
    
    package func markAsUsed() async throws {
        @Dependency(\.defaultDatabase) var db
        
        let now = Date()
        _ = try await db.write { db in
            try await Database.Identity.BackupCode
                .update { code in
                    code.isUsed = true
                    code.usedAt = now
                }
                .where { $0.id.eq(self.id) }
                .execute(db)
        }
    }
    
    package static func deleteForIdentity(_ identityId: UUID) async throws {
        @Dependency(\.defaultDatabase) var db
        _ = try await db.write { db in
            try await Database.Identity.BackupCode
                .delete()
                .where { $0.identityId.eq(identityId) }
                .execute(db)
        }
    }
}

// MARK: - Helper Functions

extension Database.Identity.BackupCode {
    /// Hash a backup code for storage
    package static func hashCode(_ code: String) throws -> String {
        // Use Bcrypt like passwords for secure hashing
        return try Bcrypt.hash(code)
    }
    
    /// Verify a code against its hash
    package static func verifyCode(_ code: String, hash: String) throws -> Bool {
        return try Bcrypt.verify(code, created: hash)
    }
    
    /// Generate a random backup code
    package static func generateCode(length: Int = 8) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var code = ""
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<characters.count)
            let index = characters.index(characters.startIndex, offsetBy: randomIndex)
            code += String(characters[index])
        }
        return code
    }
}
