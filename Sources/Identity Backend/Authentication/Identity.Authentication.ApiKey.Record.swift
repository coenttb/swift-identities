import Dependencies
import Foundation
import IdentitiesTypes
import Records

extension Identity.Authentication {
  public enum ApiKey {}
}

extension Identity.Authentication.ApiKey {
  @Table("identity_api_keys")
  public struct Record: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = Tagged<Self, UUID>

    public let id: Identity.Authentication.ApiKey.Record.ID
    package var name: String
    package var key: String
    package var scopes: [String]  // Maps to TEXT[] column in PostgreSQL
    package var identityId: Identity.ID
    package var isActive: Bool = true
    package var rateLimit: Int = 1000
    package var validUntil: Date
    package var createdAt: Date = Date()
    package var lastUsedAt: Date?

    package init(
      id: Identity.Authentication.ApiKey.Record.ID,
      name: String,
      key: String,
      scopes: [String],
      identityId: Identity.ID,
      isActive: Bool = true,
      rateLimit: Int = 1000,
      validUntil: Date,
      createdAt: Date = Date(),
      lastUsedAt: Date? = nil
    ) {
      self.id = id
      self.name = name
      self.key = key
      self.scopes = scopes
      self.identityId = identityId
      self.isActive = isActive
      self.rateLimit = rateLimit
      self.validUntil = validUntil
      self.createdAt = createdAt
      self.lastUsedAt = lastUsedAt
    }

    package init(
      id: Identity.Authentication.ApiKey.Record.ID,
      name: String,
      identityId: Identity.ID,
      scopes: [String] = [],
      rateLimit: Int = 1000,
      validUntil: Date? = nil
    ) {
      @Dependency(\.date) var date

      self.id = id
      self.name = name
      self.identityId = identityId
      self.key = Self.generateKey()
      self.scopes = scopes
      self.isActive = true
      self.rateLimit = rateLimit
      self.validUntil = validUntil ?? date().addingTimeInterval(365 * 24 * 3600)  // Default 1 year
      self.createdAt = date()
      self.lastUsedAt = nil
    }

    private static func generateKey() -> String {
      @Dependency(\.uuid) var uuid
      @Dependency(\.context) var context

      let prefix = "pk_"
      let env =
        switch context {
        case .live: "live"
        case .test: "test"
        case .preview: "preview"
        }

      let key = uuid().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
      return "\(prefix)\(env)_\(key)"
    }
  }
}

// MARK: - Query Helpers

extension Identity.Authentication.ApiKey.Record {
  package static func findByKey(_ key: String) -> Where<Identity.Authentication.ApiKey.Record> {
    Self.where { $0.key.eq(key) }
  }

  package static func findByIdentity(_ identityId: Identity.ID) -> Where<
    Identity.Authentication.ApiKey.Record
  > {
    Self.where { $0.identityId.eq(identityId) }
  }

  package static var active: Where<Identity.Authentication.ApiKey.Record> {
    Self.where { apiKey in
      apiKey.isActive && apiKey.validUntil > Date()
    }
  }

  package static var inactive: Where<Identity.Authentication.ApiKey.Record> {
    Self.where { apiKey in
      !apiKey.isActive || apiKey.validUntil <= Date()
    }
  }
}

// MARK: - Validation & Usage

extension Identity.Authentication.ApiKey.Record {
  package var isValid: Bool {
    @Dependency(\.date) var date
    return isActive && validUntil > date()
  }

  package var isExpired: Bool {
    @Dependency(\.date) var date
    return validUntil <= date()
  }

  package func hasScope(_ scope: String) -> Bool {
    scopes.contains(scope)
  }

  package func hasAnyScope(_ scopes: [String]) -> Bool {
    !Set(self.scopes).isDisjoint(with: Set(scopes))
  }

  package func hasAllScopes(_ scopes: [String]) -> Bool {
    Set(scopes).isSubset(of: Set(self.scopes))
  }

  package mutating func markAsUsed() {
    @Dependency(\.date) var date
    self.lastUsedAt = date()
  }

  package mutating func deactivate() {
    self.isActive = false
  }

  package mutating func activate() {
    self.isActive = true
  }
}

extension Identity.Authentication.ApiKey.Record {

  /// Single query to validate API key and get associated identity
  /// Replaces: findByKey + separate identity lookup
  package static func authenticateWithKey(_ key: String) async throws -> ApiKeyWithIdentity? {
    @Dependency(\.defaultDatabase) var db
    @Dependency(\.date) var date

    return try await db.write { db in
      // Get API key with identity in single query
      let result = try await Identity.Authentication.ApiKey.Record
        .where { $0.key.eq(key) }
        .where { $0.isActive.eq(true) }
        .join(Identity.Record.all) { apiKey, identity in
          apiKey.identityId.eq(identity.id)
        }
        .select { apiKey, identity in
          ApiKeyWithIdentity.Columns(
            apiKey: apiKey,
            identity: identity
          )
        }
        .fetchOne(db)

      // Update last used timestamp atomically if found
      if let result = result {
        try await Identity.Authentication.ApiKey.Record
          .where { $0.id.eq(result.apiKey.id) }
          .update { apiKey in
            apiKey.lastUsedAt = date()
          }
          .execute(db)
      }

      return result
    }
  }

  /// Batch deactivate API keys
  package static func deactivateMultiple(ids: [Identity.Authentication.ApiKey.Record.ID])
    async throws
  {
    @Dependency(\.defaultDatabase) var db

    guard !ids.isEmpty else { return }

    try await db.write { db in
      // TODO: When swift-structured-queries supports WHERE IN, replace with:
      // .where { $0.id.in(ids) }
      for id in ids {
        try await Identity.Authentication.ApiKey.Record
          .where { $0.id.eq(id) }
          .update { apiKey in
            apiKey.isActive = false
          }
          .execute(db)
      }
    }
  }
}

@Selection
package struct ApiKeyWithIdentity: Sendable {
  package let apiKey: Identity.Authentication.ApiKey.Record
  package let identity: Identity.Record
}
