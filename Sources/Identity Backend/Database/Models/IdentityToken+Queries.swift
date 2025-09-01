import Foundation
import Records
import Dependencies

// MARK: - Database Operations

extension Database.Identity.Token {
    
    // Async initializer that creates and persists to database
    package init(
        identityId: UUID,
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
            try await Database.Identity.Token.insert { `self` }.execute(db)
        }
    }
    
    package static func findValid(value: String, type: TokenType) async throws -> Database.Identity.Token? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.Token
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
            try await Database.Identity.Token
                .delete()
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
    
    package static func invalidateAllForIdentity(_ identityId: UUID, type: TokenType? = nil) async throws {
        @Dependency(\.defaultDatabase) var db
        
        try await db.write { db in
            if let type = type {
                try await Database.Identity.Token
                    .delete()
                    .where { $0.identityId.eq(identityId) }
                    .where { $0.type.eq(type) }
                    .execute(db)
            } else {
                try await Database.Identity.Token
                    .delete()
                    .where { $0.identityId.eq(identityId) }
                    .execute(db)
            }
        }
    }
    
    package static func cleanupExpired() async throws {
        @Dependency(\.defaultDatabase) var db
        try await db.write { db in
            try await Database.Identity.Token
                .delete()
                .where { token in
                    #sql("\(token.validUntil) <= CURRENT_TIMESTAMP")
                }
                .execute(db)
        }
    }
}
