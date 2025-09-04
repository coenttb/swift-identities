import Foundation
import Records
import Dependencies
import EmailAddress
import Vapor

// MARK: - Database Operations

extension Database.Identity {
    
    // Async initializer that creates and persists to database
    package init(
        email: EmailAddress,
        password: String,
        emailVerificationStatus: EmailVerificationStatus = .unverified
    ) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        
        let id = uuid()
        try self.init(
            id: id,
            email: email,
            password: password,
            emailVerificationStatus: emailVerificationStatus
        )
        
        try await db.write { [`self` = self] db in
            try await Database.Identity.insert { `self` }.execute(db)
        }
    }
    
    package static func findByEmail(_ email: EmailAddress) async throws -> Database.Identity? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.findByEmail(email).fetchOne(db)
        }
    }
    
    package static func findByEmail(_ email: String) async throws -> Database.Identity? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.findByEmail(email).fetchOne(db)
        }
    }
    
    package static func findById(_ id: UUID) async throws -> Database.Identity? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.where { $0.id.eq(id) }.fetchOne(db)
        }
    }
    
    package func save() async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        var updated = self
        updated.updatedAt = date()
        
        _ = try await db.write { [updated] db in
            try await Database.Identity
                .where { $0.id.eq(self.id) }
                .update { _ in
                    updated
                }
                .execute(db)
        }
    }
    
    package static func delete(id: UUID) async throws {
        @Dependency(\.defaultDatabase) var db
        try await db.write { db in
            try await Database.Identity
                .delete()
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
    
    package static func verifyPassword(email: EmailAddress, password: String) async throws -> Database.Identity? {
        @Dependency(\.date) var date
        
        guard let identity = try await findByEmail(email) else {
            return nil
        }
        
        guard try identity.verifyPassword(password) else {
            return nil
        }
        
        // Update last login using optimized method
        try await updateLastLogin(id: identity.id)
        
        var updated = identity
        updated.lastLoginAt = date()
        
        return updated
    }
    
    package mutating func updatePassword(_ newPassword: String) async throws {
        try self.setPassword(newPassword)
        self.sessionVersion += 1 // Invalidate all existing sessions
        try await self.save()
    }
    
    package mutating func updateEmailVerificationStatus(_ status: EmailVerificationStatus) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        let id = self.id
        let updatedAt = date()
        
        _ = try await db.write { db in
            try await Database.Identity
                .where { $0.id.eq(id) }
                .update { identity in
                    identity.emailVerificationStatus = status
                    identity.updatedAt = updatedAt
                }
                .execute(db)
        }
        self.emailVerificationStatus = status
        self.updatedAt = updatedAt
    }
}
