import Foundation
import Records
import TOTP
import RFC_6238

extension Identity {
    public enum TOTP {}
}

extension Database.Identity {
    @Table("identity_totp")
    public struct TOTP: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public let identityId: UUID
        public let secret: String // Encrypted base32 secret
        public let isConfirmed: Bool
        public let algorithm: String
        public let digits: Int // Usually 6
        public let timeStep: Int // Usually 30 seconds
        public let createdAt: Date
        public let confirmedAt: Date?
        public let lastUsedAt: Date?
        public let usageCount: Int
        
        package init(
            id: UUID = UUID(),
            identityId: UUID,
            secret: String,
            isConfirmed: Bool = false,
            algorithm: RFC_6238.TOTP.Algorithm = .sha1,
            digits: Int = 6,
            timeStep: Int = 30,
            createdAt: Date = Date(),
            confirmedAt: Date? = nil,
            lastUsedAt: Date? = nil,
            usageCount: Int = 0
        ) {
            self.id = id
            self.identityId = identityId
            self.secret = secret
            self.isConfirmed = isConfirmed
            self.algorithm = algorithm.rawValue
            self.digits = digits
            self.timeStep = timeStep
            self.createdAt = createdAt
            self.confirmedAt = confirmedAt
            self.lastUsedAt = lastUsedAt
            self.usageCount = usageCount
        }
    }
    
}

// MARK: - Query Helpers

extension Database.Identity.TOTP {
    package static func findByIdentity(_ identityId: UUID) -> Where<Database.Identity.TOTP> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    package static var confirmed: Where<Database.Identity.TOTP> {
        Self.where { $0.isConfirmed.eq(true) }
    }
    
    package static var unconfirmed: Where<Database.Identity.TOTP> {
        Self.where { $0.isConfirmed.eq(false) }
    }
    
    package static func findConfirmedByIdentity(_ identityId: UUID) -> Where<Database.Identity.TOTP> {
        Self.where {
            $0.identityId.eq(identityId)
                .and($0.isConfirmed.eq(true))
        }
    }
}
