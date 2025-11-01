import Foundation
import Records

extension Identity {
  /// Audit log for tracking changes to identity-related tables
  ///
  /// This table automatically captures all INSERT, UPDATE, and DELETE operations
  /// on critical security tables using PostgreSQL triggers. The audit trail provides:
  ///
  /// - **Security**: Track unauthorized changes and security breaches
  /// - **Compliance**: Meet GDPR, SOC2, and other regulatory requirements
  /// - **Debugging**: Investigate how data reached an unexpected state
  /// - **Accountability**: Know who made what changes and when
  ///
  /// ## Audited Tables
  ///
  /// - `identities`: Password changes, email updates, verification status
  /// - `identity_api_keys`: API key creation, activation, revocation
  /// - `identity_totp`: MFA setup, confirmation, removal
  ///
  /// ## Example Queries
  ///
  /// ```swift
  /// // Get all changes to a specific identity
  /// let changes = try await Identity.Audit.Record
  ///     .where { $0.tableName == "identities" }
  ///     .where { audit in
  ///         audit.oldData.contains("\"id\":\"\(identityId.uuidString)\"")
  ///             .or(audit.newData.contains("\"id\":\"\(identityId.uuidString)\""))
  ///     }
  ///     .order(by: \.changedAt, .descending)
  ///     .fetchAll(db)
  ///
  /// // Find password changes in last 24 hours
  /// let passwordChanges = try await Identity.Audit.Record
  ///     .where { $0.tableName == "identities" }
  ///     .where { $0.operation == "UPDATE" }
  ///     .where { audit in
  ///         audit.newData.contains("passwordHash")
  ///             .and(audit.changedAt > Date().addingTimeInterval(-86400))
  ///     }
  ///     .fetchAll(db)
  /// ```
  ///
  /// ## Storage & Retention
  ///
  /// - Audit logs use JSONB for efficient storage with compression
  /// - Consider implementing automatic purging of logs older than 1-2 years
  /// - Estimated storage: ~2-3x the size of audited tables
  ///
  /// ## Privacy Considerations
  ///
  /// - Contains sensitive data (password hashes, email addresses)
  /// - Access should be restricted to administrators
  /// - GDPR: Consider purging when user requests "right to erasure"
  ///
  @Table("identity_audit")
  public struct Audit: Codable, Equatable, AuditTable, Sendable {
    public let id: Int

    /// Name of the table that was modified
    public var tableName: String

    /// SQL operation performed: INSERT, UPDATE, or DELETE
    public var operation: String

    /// JSONB snapshot of the row before the change
    /// - NULL for INSERT operations
    /// - Contains full row data for UPDATE and DELETE
    public var oldData: String?

    /// JSONB snapshot of the row after the change
    /// - Contains full row data for INSERT and UPDATE
    /// - NULL for DELETE operations
    public var newData: String?

    /// Timestamp when the change occurred
    public var changedAt: Date

    /// Identifier of who made the change
    /// - For user-initiated changes: Identity.ID
    /// - For system changes: "system"
    /// - For database default: PostgreSQL current_user
    public var changedBy: String

    public init(
      id: Int,
      tableName: String,
      operation: String,
      oldData: String?,
      newData: String?,
      changedAt: Date,
      changedBy: String
    ) {
      self.id = id
      self.tableName = tableName
      self.operation = operation
      self.oldData = oldData
      self.newData = newData
      self.changedAt = changedAt
      self.changedBy = changedBy
    }
  }
}

// MARK: - Query Helpers

extension Identity.Audit {
  /// Audit records for a specific table
  public static func forTable(_ tableName: String) -> Where<Identity.Audit> {
    Identity.Audit.where { $0.tableName == tableName }
  }

  /// Audit records for INSERT operations
  public static var inserts: Where<Identity.Audit> {
    Identity.Audit.where { $0.operation == "INSERT" }
  }

  /// Audit records for UPDATE operations
  public static var updates: Where<Identity.Audit> {
    Identity.Audit.where { $0.operation == "UPDATE" }
  }

  /// Audit records for DELETE operations
  public static var deletes: Where<Identity.Audit> {
    Identity.Audit.where { $0.operation == "DELETE" }
  }

  /// Audit records within a time range
  public static func between(start: Date, end: Date) -> Where<Identity.Audit> {
    Identity.Audit.where { audit in
      audit.changedAt >= start && audit.changedAt <= end
    }
  }

  /// Audit records changed by a specific user
  public static func changedBy(_ userId: String) -> Where<Identity.Audit> {
    Identity.Audit.where { $0.changedBy == userId }
  }
}

// MARK: - Convenience Types

extension Identity.Audit {
  /// Common table names for type-safe queries
  public enum TableName: String {
    case identities = "identities"
    case apiKeys = "identity_api_keys"
    case totp = "identity_totp"
    case backupCodes = "identity_backup_codes"
    case oauthConnections = "oauth_connections"

    /// Get audit records for this table
    public var auditRecords: Where<Identity.Audit> {
      Identity.Audit.forTable(self.rawValue)
    }
  }

  /// SQL operation types
  public enum Operation: String {
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
  }
}
