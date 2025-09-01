import Foundation
import Records
import Dependencies

// MARK: - Database Operations

extension IdentityApiKey {
    
    // Async initializer that creates and persists to database
    package init(
        name: String,
        identityId: UUID,
        scopes: [String] = [],
        rateLimit: Int = 1000
    ) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        
        self.init(
            id: uuid(),
            name: name,
            identityId: identityId,
            scopes: scopes,
            rateLimit: rateLimit
        )
        
        try await db.write { [`self` = self] db in
            try await IdentityApiKey.insert { `self` }.execute(db)
        }
    }
    
    package static func findByKey(_ key: String) async throws -> IdentityApiKey? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await IdentityApiKey.findByKey(key).where { $0.isActive }.fetchOne(db)
        }
    }
    
    package mutating func updateLastUsed() async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        self.lastUsedAt = date()
        let lastUsedAt = self.lastUsedAt
        let id = self.id
        
        try await db.write { db in
            try await IdentityApiKey
                .update { apiKey in
                    apiKey.lastUsedAt = lastUsedAt
                }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
    
    package mutating func deactivate() async throws {
        @Dependency(\.defaultDatabase) var db
        
        self.isActive = false
        let id = self.id
        
        try await db.write { db in
            try await IdentityApiKey
                .update { apiKey in
                    apiKey.isActive = false
                }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
    
    package static func listForIdentity(_ identityId: UUID) async throws -> [IdentityApiKey] {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await IdentityApiKey.findByIdentity(identityId).fetchAll(db)
        }
    }
}
