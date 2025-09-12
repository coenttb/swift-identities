import Foundation
import Records
import Dependencies

// MARK: - Database Operations

extension Identity.Token.Record {
    
    // REMOVED: Async init that auto-saves to database
    // Create tokens inline within transactions for proper atomicity
    
    // Keep cleanupExpired as it's a maintenance operation that doesn't break transaction boundaries
    // It's called as a standalone cleanup task, not within other transactions
    package static func cleanupExpired() async throws {
        @Dependency(\.defaultDatabase) var db
        try await db.write { db in
            try await Identity.Token.Record
                .delete()
                .where { token in
                    token.validUntil <= Date()
                }
                .execute(db)
        }
    }
}
