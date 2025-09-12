import Foundation
import Records
import Dependencies

// MARK: - Database Operations

extension Identity.Authentication.Token.Record {
    
    // Async initializer that creates and persists to database
    package init(
        identityId: Identity.ID,
        type: TokenType,
        validityHours: Int = 1
    ) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        @Dependency(\.date) var date
        
        self.init(
            id: uuid(),
            identityId: identityId,
            type: type,
            validUntil: date().addingTimeInterval(TimeInterval(validityHours * 3600))
        )
        
        try await db.write { [`self` = self] db in
            try await Identity.Authentication.Token.Record.insert { `self` }.execute(db)
        }
    }
    
    package static func findValid(value: String, type: TokenType) async throws -> Identity.Authentication.Token.Record? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Identity.Authentication.Token.Record
                .where { token in
                    token.value.eq(value) &&
                    token.type.eq(type) &&
                    #sql("\(token.validUntil) > CURRENT_TIMESTAMP")
                }
                .fetchOne(db)
        }
    }
    
    package static func invalidate(id: UUID) async throws {
        @Dependency(\.defaultDatabase) var db
        try await db.write { db in
            try await Identity.Authentication.Token.Record
                .delete()
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
    
    package static func invalidateAllForIdentity(_ identityId: Identity.ID, type: TokenType? = nil) async throws {
        @Dependency(\.defaultDatabase) var db
        
        try await db.write { db in
            if let type = type {
                try await Identity.Authentication.Token.Record
                    .delete()
                    .where { $0.identityId.eq(identityId) }
                    .where { $0.type.eq(type) }
                    .execute(db)
            } else {
                try await Identity.Authentication.Token.Record
                    .delete()
                    .where { $0.identityId.eq(identityId) }
                    .execute(db)
            }
        }
    }
    
    package static func cleanupExpired() async throws {
        @Dependency(\.defaultDatabase) var db
        try await db.write { db in
            try await Identity.Authentication.Token.Record
                .delete()
                .where { token in
                    #sql("\(token.validUntil) <= CURRENT_TIMESTAMP")
                }
                .execute(db)
        }
    }
}
