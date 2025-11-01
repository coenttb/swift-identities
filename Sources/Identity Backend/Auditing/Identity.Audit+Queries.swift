import Foundation
import Records
import Dependencies

// MARK: - Audit Query Helpers

extension Identity.Audit {
    /// Get audit history for a specific table
    ///
    /// Retrieves all changes for a given table name.
    /// Results are ordered by most recent first.
    ///
    /// ## Example
    /// ```swift
    /// let history = try await Identity.Audit.historyFor(
    ///     tableName: "identities",
    ///     limit: 100
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - tableName: The table to get history for
    ///   - limit: Maximum number of records to return (default: 100)
    /// - Returns: Array of audit records
    public static func historyFor(
        tableName: String,
        limit: Int = 100
    ) async throws -> [Identity.Audit] {
        @Dependency(\.defaultDatabase) var db

        return try await db.read { db in
            try await Identity.Audit
                .forTable(tableName)
                .order { $0.changedAt.desc() }
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Get recent audit records for the identities table
    ///
    /// Returns password changes, email updates, verification status changes, etc.
    ///
    /// - Parameter limit: Maximum number of records (default: 100)
    /// - Returns: Array of audit records showing identity changes
    public static func recentIdentityChanges(
        limit: Int = 100
    ) async throws -> [Identity.Audit] {
        @Dependency(\.defaultDatabase) var db

        return try await db.read { db in
            try await Identity.Audit
                .forTable("identities")
                .order { $0.changedAt.desc() }
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Get recent MFA-related changes
    ///
    /// Tracks TOTP setup, confirmation, and removal.
    ///
    /// - Parameter limit: Maximum number of records (default: 100)
    /// - Returns: Array of audit records showing MFA changes
    public static func recentMFAChanges(
        limit: Int = 100
    ) async throws -> [Identity.Audit] {
        @Dependency(\.defaultDatabase) var db

        return try await db.read { db in
            try await Identity.Audit
                .forTable("identity_totp")
                .order { $0.changedAt.desc() }
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Get recent API key lifecycle events
    ///
    /// Shows API key creation, activation, deactivation, and deletion.
    ///
    /// - Parameter limit: Maximum number of records (default: 100)
    /// - Returns: Array of audit records showing API key changes
    public static func recentAPIKeyChanges(
        limit: Int = 100
    ) async throws -> [Identity.Audit] {
        @Dependency(\.defaultDatabase) var db

        return try await db.read { db in
            try await Identity.Audit
                .forTable("identity_api_keys")
                .order { $0.changedAt.desc() }
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Get recent security-relevant changes across all audited tables
    ///
    /// Useful for security monitoring and anomaly detection.
    ///
    /// - Parameters:
    ///   - since: Only return changes after this date
    ///   - limit: Maximum number of records (default: 100)
    /// - Returns: Recent security-relevant audit records
    public static func recentSecurityChanges(
        since: Date,
        limit: Int = 100
    ) async throws -> [Identity.Audit] {
        @Dependency(\.defaultDatabase) var db

        return try await db.read { db in
            try await Identity.Audit
                .where { $0.changedAt >= since }
                .order { $0.changedAt.desc() }
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Get all deletions across audited tables
    ///
    /// Shows what data was deleted and when.
    ///
    /// - Parameter limit: Maximum number of records (default: 100)
    /// - Returns: Deletion audit records
    public static func recentDeletions(
        limit: Int = 100
    ) async throws -> [Identity.Audit] {
        @Dependency(\.defaultDatabase) var db

        return try await db.read { db in
            try await Identity.Audit
                .deletes
                .order { $0.changedAt.desc() }
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Count audit records for a specific table
    ///
    /// Useful for monitoring audit log growth and storage planning.
    ///
    /// - Parameter tableName: Name of the table to count audits for
    /// - Returns: Total number of audit records for that table
    public static func countFor(
        tableName: String
    ) async throws -> Int {
        @Dependency(\.defaultDatabase) var db

        return try await db.read { db in
            try await Identity.Audit
                .forTable(tableName)
                .fetchCount(db)
        }
    }

    /// Purge old audit records
    ///
    /// For GDPR compliance or storage management, remove audit records older than a threshold.
    ///
    /// ⚠️ **Warning**: This permanently deletes audit history. Use with caution.
    ///
    /// - Parameter olderThan: Delete records before this date
    /// - Returns: Number of records deleted
    @discardableResult
    public static func purgeRecords(
        olderThan: Date
    ) async throws -> Int {
        @Dependency(\.defaultDatabase) var db

        // First count how many will be deleted
        let count = try await db.read { db in
            try await Identity.Audit
                .where { $0.changedAt < olderThan }
                .fetchCount(db)
        }

        // Then delete them
        try await db.write { db in
            try await Identity.Audit
                .where { $0.changedAt < olderThan }
                .delete()
                .execute(db)
        }

        return count
    }
}

// MARK: - Decoded Audit Data

extension Identity.Audit {
    /// Decode the old data JSONB field to a specific type
    ///
    /// ## Example
    /// ```swift
    /// let audit = try await Identity.Audit.historyFor(identityId: user.id).first!
    /// let oldIdentity: Identity.Record? = try audit.decodeOldData()
    /// ```
    public func decodeOldData<T: Decodable>() throws -> T? {
        guard let oldData = oldData,
              let data = oldData.data(using: .utf8) else {
            return nil
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Decode the new data JSONB field to a specific type
    ///
    /// ## Example
    /// ```swift
    /// let audit = try await Identity.Audit.historyFor(identityId: user.id).first!
    /// let newIdentity: Identity.Record? = try audit.decodeNewData()
    /// ```
    public func decodeNewData<T: Decodable>() throws -> T? {
        guard let newData = newData,
              let data = newData.data(using: .utf8) else {
            return nil
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
