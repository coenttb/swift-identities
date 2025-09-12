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
        package var email: EmailAddress
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
            self.email = email
            self.passwordHash = passwordHash
            self.emailVerificationStatus = emailVerificationStatus
            self.sessionVersion = sessionVersion
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.lastLoginAt = lastLoginAt
        }
    }
}

extension EmailAddress: @retroactive QueryExpression {}
extension EmailAddress: @retroactive QueryRepresentable {}
extension EmailAddress: @retroactive QueryDecodable {}
extension EmailAddress: @retroactive _OptionalPromotable {}
extension EmailAddress: @retroactive QueryBindable {}

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

extension Identity.Record {
    
//    /// Batch invalidate sessions for multiple identities
//    /// Returns count of identities updated
//    package static func invalidateSessionsBatch(identityIds: [UUID]) async throws -> Int {
//        @Dependency(\.defaultDatabase) var db
//        @Dependency(\.date) var date
//
//        guard !identityIds.isEmpty else { return 0 }
//
//        var updatedCount = 0
//
//        try await db.write { db in
//            // TODO: When swift-structured-queries supports WHERE IN, replace with single query
//            for identityId in identityIds {
//                try await Identity.Record
//                    .where { $0.id.eq(identityId) }
//                    .update { identity in
//                        identity.sessionVersion = identity.sessionVersion + 1
//                        identity.updatedAt = date()
//                    }
//                    .execute(db)
//                updatedCount += 1
//            }
//        }
//
//        return updatedCount
//    }
    
    /// Check multiple emails exist in single query
    /// Returns dictionary of email -> exists
    package static func emailsExist(_ emails: [EmailAddress]) async throws -> [EmailAddress: Bool] {
        @Dependency(\.defaultDatabase) var db
        
        guard !emails.isEmpty else { return [:] }
        
        // Get all existing emails in one query
        let existingEmails = try await db.read { db in
            var results: Set<String> = []
            for email in emails {
                let exists = try await Identity.Record
                    .where { $0.email.eq(email) }
                    .fetchCount(db) > 0
                if exists {
                    results.insert(email.rawValue)
                }
            }
            return results
        }
        
        // Build result dictionary
        var result: [EmailAddress: Bool] = [:]
        for email in emails {
            result[email] = existingEmails.contains(email.rawValue)
        }
        
        return result
    }
}


extension Identity.Record {
     static func update(from identity: Identity.Record) -> (inout Updates<Identity.Record>) -> Void {
         return { updates in
             updates.email = identity.email
             updates.passwordHash = identity.passwordHash
             updates.emailVerificationStatus = identity.emailVerificationStatus
             updates.sessionVersion = identity.sessionVersion
             updates.updatedAt = identity.updatedAt
             updates.lastLoginAt = identity.lastLoginAt
         }
     }
 }
