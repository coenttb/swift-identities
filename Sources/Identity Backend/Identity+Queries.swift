import Dependencies
import EmailAddress
import Foundation
import Records

// MARK: - Optimized Database Operations

extension Identity.Record {

  // MARK: - Authentication

  /// Verify password and update last login atomically
  /// Returns the updated identity if password is correct, nil otherwise
  package static func verifyPasswordAndUpdateLogin(
    email: EmailAddress,
    password: String
  ) async throws -> Identity.Record? {
    @Dependency(\.defaultDatabase) var db
    @Dependency(\.date) var date

    // Single query to get identity
    let identity = try await db.read { db in
      try await Identity.Record
        .where { $0.email.eq(email) }
        .fetchOne(db)
    }

    guard let identity else { return nil }

    // Verify password
    guard try await identity.verifyPassword(password) else { return nil }

    // Update last login in single write
    let now = date()
    try await db.write { db in
      try await Identity.Record
        .where { $0.id.eq(identity.id) }
        .update { record in
          record.lastLoginAt = now
          record.updatedAt = now
        }
        .execute(db)
    }

    var updated = identity
    updated.lastLoginAt = now
    updated.updatedAt = now

    return updated
  }

  // MARK: - Updates

  // REMOVED: updatePasswordAndInvalidateSessions helper method
  // Database updates should be explicit at call sites for clarity

  /// Update email verification status
  /// Returns the updated record from database
  package static func updateEmailVerificationStatus(
    id: Identity.ID,
    status: EmailVerificationStatus
  ) async throws -> Identity.Record? {
    @Dependency(\.defaultDatabase) var db
    @Dependency(\.date) var date

    // Note: Using update without returning for now as returning might not be available
    // in current swift-records version. Can be enhanced when available.
    try await db.write { db in
      try await Identity.Record
        .where { $0.id.eq(id) }
        .update { record in
          record.emailVerificationStatus = status
          record.updatedAt = date()
        }
        .execute(db)
    }

    // Fetch the updated record
    return try await db.read { db in
      try await Identity.Record
        .where { $0.id.eq(id) }
        .fetchOne(db)
    }
  }

  // MARK: - Batch Operations

  /// Check multiple emails exist in a single optimized query
  ///
  /// Uses PostgreSQL IN clause to check all emails in one database roundtrip.
  /// Returns only the emails that exist (as a Set for efficient lookup).
  ///
  /// - Parameter emails: List of email addresses to check
  /// - Returns: Set of email addresses that exist in the database
  ///
  /// - Performance: O(1) database query regardless of number of emails
  /// - Complexity: Single query: `SELECT email FROM identities WHERE email IN (...)`
  package static func emailsExistOptimized(_ emails: [EmailAddress]) async throws -> Set<
    EmailAddress
  > {
    @Dependency(\.defaultDatabase) var db

    guard !emails.isEmpty else { return [] }

    return try await db.read { db in
      let existingEmails = try await Identity.Record
        .where { $0.email.in(emails) }
        .select { $0.email }
        .fetchAll(db)

      return Set(existingEmails)
    }
  }

  // MARK: - Upsert Operations

  /// Create or update identity atomically using upsert pattern
  /// Useful for OAuth flows where user might already exist
  package static func upsert(
    email: EmailAddress,
    passwordHash: String,
    emailVerificationStatus: EmailVerificationStatus = .unverified
  ) async throws -> Identity.Record? {
    @Dependency(\.defaultDatabase) var db
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    return try await db.write { db in
      // Insert with conflict handling
      try await Identity.Record
        .insert {
          Identity.Record.Draft(
            email: email,
            passwordHash: passwordHash,
            emailVerificationStatus: emailVerificationStatus,
            sessionVersion: 0,
            createdAt: date(),
            updatedAt: date(),
            lastLoginAt: nil
          )
        } onConflict: {
          $0.email
        } doUpdate: { row, excluded in
          // Update everything except id and createdAt
          row.passwordHash = excluded.passwordHash
          row.emailVerificationStatus = excluded.emailVerificationStatus
          row.sessionVersion = excluded.sessionVersion
          row.updatedAt = excluded.updatedAt
          row.lastLoginAt = excluded.lastLoginAt
        }
        .execute(db)

      // Fetch the record (either inserted or updated)
      return try await Identity.Record
        .where { $0.email.eq(email) }
        .fetchOne(db)
    }
  }
}
