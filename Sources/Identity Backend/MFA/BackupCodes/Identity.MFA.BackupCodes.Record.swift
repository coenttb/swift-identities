import Foundation
import Records
import IdentitiesTypes

extension Identity.MFA.BackupCodes {
    @Table("identity_backup_codes")
    public struct Record: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public let identityId: Identity.ID
        public let codeHash: String // Hashed backup code
        public let isUsed: Bool
        public let createdAt: Date
        public let usedAt: Date?
    }
}

extension Identity.MFA.BackupCodes.Record.Draft {
    package init(
        id: UUID? = nil,
        identityId: Identity.ID,
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

// MARK: - Query Helpers

extension Identity.MFA.BackupCodes.Record {
    package static func findByIdentity(_ identityId: Identity.ID) -> Where<Identity.MFA.BackupCodes.Record> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    package static var unused: Where<Identity.MFA.BackupCodes.Record> {
        Self.where { $0.isUsed.eq(false) }
    }
    
    package static var used: Where<Identity.MFA.BackupCodes.Record> {
        Self.where { $0.isUsed.eq(true) }
    }
    
    package static func findUnusedByIdentity(_ identityId: Identity.ID) -> Where<Identity.MFA.BackupCodes.Record> {
        Self.where { 
            $0.identityId.eq(identityId)
                .and($0.isUsed.eq(false))
        }
    }
}

