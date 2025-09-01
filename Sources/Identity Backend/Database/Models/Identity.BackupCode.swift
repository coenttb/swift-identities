import Foundation
import Records

extension Identity {
    public enum BackupCode {}
}

extension Database.Identity {
    @Table("identity_backup_codes")
    public struct BackupCode: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public let identityId: UUID
        public let codeHash: String // Hashed backup code
        public let isUsed: Bool
        public let createdAt: Date
        public let usedAt: Date?
        
        package init(
            id: UUID = UUID(),
            identityId: UUID,
            codeHash: String,
            isUsed: Bool = false,
            createdAt: Date = Date(),
            usedAt: Date? = nil
        ) {
            self.id = id
            self.identityId = identityId
            self.codeHash = codeHash
            self.isUsed = isUsed
            self.createdAt = createdAt
            self.usedAt = usedAt
        }
    }
    
}

// MARK: - Query Helpers

extension Database.Identity.BackupCode {
    package static func findByIdentity(_ identityId: UUID) -> Where<Database.Identity.BackupCode> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    package static var unused: Where<Database.Identity.BackupCode> {
        Self.where { $0.isUsed.eq(false) }
    }
    
    package static var used: Where<Database.Identity.BackupCode> {
        Self.where { $0.isUsed.eq(true) }
    }
    
    package static func findUnusedByIdentity(_ identityId: UUID) -> Where<Database.Identity.BackupCode> {
        Self.where { 
            $0.identityId.eq(identityId)
                .and($0.isUsed.eq(false))
        }
    }
}
