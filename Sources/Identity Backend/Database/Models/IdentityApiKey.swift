import Foundation
import Records
import Dependencies

@Table("identity_api_keys")
package struct IdentityApiKey: Codable, Equatable, Identifiable, Sendable {
    package let id: UUID
    package var name: String
    package var key: String
    package var scopes: String  // Store as JSON string, maps to jsonb column in PostgreSQL
    package var identityId: UUID
    package var isActive: Bool = true
    package var rateLimit: Int = 1000
    package var validUntil: Date
    package var createdAt: Date = Date()
    package var lastUsedAt: Date?
    
    // Computed property for working with scopes as array
    package var scopesArray: [String] {
        get {
            guard !scopes.isEmpty,
                  let data = scopes.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                scopes = string
            } else {
                scopes = "[]"
            }
        }
    }
    
    package init(
        id: UUID,
        name: String,
        key: String,
        scopes: [String],
        identityId: UUID,
        isActive: Bool = true,
        rateLimit: Int = 1000,
        validUntil: Date,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.key = key
        if let data = try? JSONEncoder().encode(scopes),
           let string = String(data: data, encoding: .utf8) {
            self.scopes = string
        } else {
            self.scopes = "[]"
        }
        self.identityId = identityId
        self.isActive = isActive
        self.rateLimit = rateLimit
        self.validUntil = validUntil
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
    
    package init(
        id: UUID,
        name: String,
        identityId: UUID,
        scopes: [String] = [],
        rateLimit: Int = 1000,
        validUntil: Date? = nil
    ) {
        @Dependency(\.date) var date
        
        self.id = id
        self.name = name
        self.identityId = identityId
        self.key = Self.generateKey()
        if let data = try? JSONEncoder().encode(scopes),
           let string = String(data: data, encoding: .utf8) {
            self.scopes = string
        } else {
            self.scopes = "[]"
        }
        self.isActive = true
        self.rateLimit = rateLimit
        self.validUntil = validUntil ?? date().addingTimeInterval(365 * 24 * 3600) // Default 1 year
        self.createdAt = date()
        self.lastUsedAt = nil
    }
    
    private static func generateKey() -> String {
        @Dependency(\.uuid) var uuid
        @Dependency(\.context) var context
        
        let prefix = "pk_"
        let env = switch context {
        case .live: "live"
        case .test: "test"
        case .preview: "preview"
        }
        
        let key = uuid().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return "\(prefix)\(env)_\(key)"
    }
}

// MARK: - Query Helpers

extension IdentityApiKey {
    package static func findByKey(_ key: String) -> Where<IdentityApiKey> {
        Self.where { $0.key.eq(key) }
    }
    
    package static func findByIdentity(_ identityId: UUID) -> Where<IdentityApiKey> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    package static var active: Where<IdentityApiKey> {
        Self.where { apiKey in
            apiKey.isActive && #sql("\(apiKey.validUntil) > CURRENT_TIMESTAMP")
        }
    }
    
    package static var inactive: Where<IdentityApiKey> {
        Self.where { apiKey in
            !apiKey.isActive || #sql("\(apiKey.validUntil) <= CURRENT_TIMESTAMP")
        }
    }
    
//    package static func activeWithScope(_ scope: String) -> Where<IdentityApiKey> {
//        Self.where { apiKey in
//            apiKey.isActive && 
//            #sql("\(apiKey.validUntil) > CURRENT_TIMESTAMP") &&
//            #sql("\(apiKey.scopes)::jsonb @> \(raw: "'")\(raw: "[\"")\(bind: scope)\(raw: "\"]")\(raw: "'")::jsonb")
//        }
//    }
}

// MARK: - Validation & Usage

extension IdentityApiKey {
    package var isValid: Bool {
        @Dependency(\.date) var date
        return isActive && validUntil > date()
    }
    
    package var isExpired: Bool {
        @Dependency(\.date) var date
        return validUntil <= date()
    }
    
    package func hasScope(_ scope: String) -> Bool {
        scopesArray.contains(scope)
    }
    
    package func hasAnyScope(_ scopes: [String]) -> Bool {
        !Set(self.scopesArray).isDisjoint(with: Set(scopes))
    }
    
    package func hasAllScopes(_ scopes: [String]) -> Bool {
        Set(scopes).isSubset(of: Set(self.scopesArray))
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
