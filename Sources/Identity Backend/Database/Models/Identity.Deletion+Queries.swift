import Foundation
import Records
import Dependencies

// MARK: - Database Operations

extension Database.Identity.Deletion {
    
    // Async initializer that creates and persists to database
    package init(
        identityId: UUID,
        reason: String? = nil,
        gracePeriodDays: Int = 30
    ) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        
        self.init(
            id: uuid(),
            identityId: identityId,
            reason: reason,
            gracePeriodDays: gracePeriodDays
        )
        
        let `self` = self
        
        _ = try await db.write { db in
            try await Database.Identity.Deletion.insert { `self` }
                .execute(db)
        }
    }
    
    package static func findPendingForIdentity(_ identityId: UUID) async throws -> Database.Identity.Deletion? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.Deletion.findByIdentity(identityId).pending
                .fetchOne(db)
        }
    }
    
    package mutating func confirm() async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        self.confirmedAt = date()
        let confirmedAt = self.confirmedAt
        let id = self.id
        
        try await db.write { db in
            try await Database.Identity.Deletion
                .update { deletion in
                    deletion.confirmedAt = confirmedAt
                }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
    
    package mutating func cancel() async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        self.cancelledAt = date()
        let cancelledAt = self.cancelledAt
        let id = self.id
        
        try await db.write { db in
            try await Database.Identity.Deletion
                .update { deletion in
                    deletion.cancelledAt = cancelledAt
                }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
    
    package static func getReadyForDeletion() async throws -> [Database.Identity.Deletion] {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.Deletion.readyForDeletion
                .fetchAll(db)
        }
    }
}
