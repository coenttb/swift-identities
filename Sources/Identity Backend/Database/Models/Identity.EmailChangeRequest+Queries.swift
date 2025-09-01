import Foundation
import Records
import Dependencies
import EmailAddress

// MARK: - Database Operations

extension Database.Identity.Email.Change.Request {
    
    // Async initializer that creates and persists to database
    package init(
        identityId: UUID,
        newEmail: EmailAddress
    ) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        
        self.init(
            id: uuid(),
            identityId: identityId,
            newEmail: newEmail
        )
        
        _ = try await db.write { [`self` = self] db in
            try await Database.Identity.Email.Change.Request.insert { `self` }
                .execute(db)
        }
    }
    
    package static func findByToken(_ token: String) async throws -> Database.Identity.Email.Change.Request? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.Email.Change.Request.findByToken(token).valid
                .fetchOne(db)
        }
    }
    
    package mutating func confirm() async throws -> Database.Identity? {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        let newEmail = self.newEmail
        let identityId = self.identityId
        let updatedAt = date()
        self.confirmedAt = date()
        let confirmedAt = self.confirmedAt
        let id = self.id
        
        try await db.write { db in
            // Update the identity's email
            try await Database.Identity
                .update { identity in
                    identity.emailString = newEmail
                    identity.updatedAt = updatedAt
                }
                .where { $0.id.eq(identityId) }
                .execute(db)
            
            // Mark request as confirmed
            try await Database.Identity.Email.Change.Request
                .update { req in
                    req.confirmedAt = confirmedAt
                }
                .where { $0.id.eq(id) }
                .execute(db)
        }
        
        // Return the updated identity
        return try await Database.Identity.findById(identityId)
    }
    
    package mutating func cancel() async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        self.cancelledAt = date()
        let cancelledAt = self.cancelledAt
        let id = self.id
        
        try await db.write { db in
            try await Database.Identity.Email.Change.Request
                .update { request in
                    request.cancelledAt = cancelledAt
                }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
}
