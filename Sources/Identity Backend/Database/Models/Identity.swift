import Foundation
import Records
import EmailAddress
import Vapor

public enum Database {}

extension Database {
    @Table("identities")
    public struct Identity: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        @Column("email")
        package var emailString: String
        package var passwordHash: String
        package var emailVerificationStatus: EmailVerificationStatus = .unverified
        package var sessionVersion: Int = 0
        package var createdAt: Date = Date()
        package var updatedAt: Date = Date()
        package var lastLoginAt: Date?
        
        public enum EmailVerificationStatus: String, Codable, QueryBindable, Sendable {
            case unverified
            case pending
            case verified
            case failed
        }
        
        package var email: EmailAddress {
            get {
                try! EmailAddress(emailString)
            }
            set {
                emailString = newValue.rawValue
            }
        }
//        
        package init(
            id: UUID,
            email: EmailAddress,
            passwordHash: String,
            emailVerificationStatus: EmailVerificationStatus = .unverified,
            sessionVersion: Int = 0,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            lastLoginAt: Date? = nil
        ) {
            self.id = id
            self.emailString = email.rawValue
            self.passwordHash = passwordHash
            self.emailVerificationStatus = emailVerificationStatus
            self.sessionVersion = sessionVersion
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.lastLoginAt = lastLoginAt
        }

    }
}

// MARK: - Password Management

extension Database.Identity {
    package mutating func setPassword(_ password: String) throws {
        self.passwordHash = try Bcrypt.hash(password)
        self.updatedAt = Date()
    }
    
    package func verifyPassword(_ password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

// MARK: - Query Helpers

extension Database.Identity {
    package static func findByEmail(_ email: String) -> Where<Database.Identity> {
        Self.where { $0.emailString.eq(email) }
    }
    
    package static func findByEmail(_ email: EmailAddress) -> Where<Database.Identity> {
        Self.where { $0.emailString.eq(email.rawValue) }
    }
    
    package static var verified: Where<Database.Identity> {
        Self.where { $0.emailVerificationStatus.eq(EmailVerificationStatus.verified) }
    }
    
    package static var unverified: Where<Database.Identity> {
        Self.where { $0.emailVerificationStatus.eq(EmailVerificationStatus.unverified) }
    }
    
    package static var pending: Where<Database.Identity> {
        Self.where { $0.emailVerificationStatus.eq(EmailVerificationStatus.pending) }
    }
}
