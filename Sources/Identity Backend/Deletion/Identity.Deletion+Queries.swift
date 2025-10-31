import Dependencies
import Foundation
import Records

// MARK: - Database Operations

extension Identity.Deletion.Record {

  // REMOVED: Async init that auto-saves to database
  // Create deletion records inline within transactions for proper atomicity

  // REMOVED: findPendingForIdentity helper method
  // Use explicit queries at call sites for clarity

  // REMOVED: mutating confirm() and cancel() methods that hide DB operations
  // Database updates should be explicit at call sites

  // Keep this as a standalone maintenance operation
  package static func getReadyForDeletion() async throws -> [Identity.Deletion.Record] {
    @Dependency(\.defaultDatabase) var db
    return try await db.read { db in
      try await Identity.Deletion.Record.readyForDeletion
        .fetchAll(db)
    }
  }
}
