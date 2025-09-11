import Foundation
import Records
import EmailAddress
import Vapor
import Dependencies
import EnvironmentVariables


extension Identity {
    @Table("identities")
    public struct Record: Codable, Equatable, Identifiable, Sendable {
        public let id: Identity.ID
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
            id: Identity.ID,
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

extension Identity.Record {
    package mutating func setPassword(_ password: String) async throws {
        @Dependency(\.envVars) var envVars
        @Dependency(\.application) var application
        
        let passwordHash: String = try await application.threadPool.runIfActive {
            try Bcrypt.hash(password, cost: envVars.bcryptCost)
        }
        
        self.passwordHash = passwordHash
        self.updatedAt = Date()
    }
    
    package func verifyPassword(_ password: String) async throws -> Bool {
        @Dependency(\.application) var application
        
        return try await application.threadPool.runIfActive {
            try Bcrypt.verify(password, created: self.passwordHash)
        }
    }
}

// MARK: - Query Helpers

extension Identity.Record {
    package static func findByEmail(_ email: String) -> Where<Identity.Record> {
        Self.where { $0.emailString.eq(email) }
    }
    
    package static func findByEmail(_ email: EmailAddress) -> Where<Identity.Record> {
        Self.where { $0.emailString.eq(email.rawValue) }
    }
    
    package static var verified: Where<Identity.Record> {
        Self.where { $0.emailVerificationStatus.eq(EmailVerificationStatus.verified) }
    }
    
    package static var unverified: Where<Identity.Record> {
        Self.where { $0.emailVerificationStatus.eq(EmailVerificationStatus.unverified) }
    }
    
    package static var pending: Where<Identity.Record> {
        Self.where { $0.emailVerificationStatus.eq(EmailVerificationStatus.pending) }
    }
}
