import Foundation
import Records
import Dependencies
import Crypto
import IdentitiesTypes

extension Identity.Token {
    @Table("identity_tokens")
    public struct Record: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        package var value: String
        package var validUntil: Date
        package var identityId: Identity.ID
        package var type: TokenType
        package var createdAt: Date = Date()
        package var lastUsedAt: Date?
        
        public struct TokenType: RawRepresentable, Codable, Hashable, QueryBindable, Sendable, ExpressibleByStringLiteral {
            public let rawValue: String
            
            public init(rawValue: String) {
                self.rawValue = rawValue
            }
            
            public init(stringLiteral value: StringLiteralType) {
                self = .init(rawValue: value)
            }
        }
        
        package init(
            id: UUID,
            value: String,
            validUntil: Date,
            identityId: Identity.ID,
            type: TokenType,
            createdAt: Date = Date(),
            lastUsedAt: Date? = nil
        ) {
            self.id = id
            self.value = value
            self.validUntil = validUntil
            self.identityId = identityId
            self.type = type
            self.createdAt = createdAt
            self.lastUsedAt = lastUsedAt
        }
        
        package init(
            id: UUID,
            identityId: Identity.ID,
            type: TokenType,
            validUntil: Date? = nil
        ) {
            @Dependency(\.date) var date
            
            self.id = id
            self.identityId = identityId
            self.type = type
            self.value = Self.generateSecureToken(type: type)
            self.validUntil = validUntil ?? date().addingTimeInterval(3600) // Default 1 hour validity
            self.createdAt = date()
            self.lastUsedAt = nil
        }
        
        private static func generateSecureToken(type: TokenType) -> String {
            switch type {
            case .emailVerification, .passwordReset, .emailChange, .accountDeletion:
                // Generate a URL-safe token for email-based verifications
                return SymmetricKey(size: .bits256)
                    .withUnsafeBytes { Data($0) }
                    .base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
            case .apiAccess:
                // Generate API key with prefix
                @Dependency(\.uuid) var uuid
                return "sk_\(uuid().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
            default:
                // Generate standard token
                return SymmetricKey(size: .bits256)
                    .withUnsafeBytes { Data($0) }
                    .base64EncodedString()
            }
        }
    }
}

// MARK: - Query Helpers

extension Identity.Token.Record {
    package static func findByValue(_ value: String) -> Where<Identity.Token.Record> {
        Self.where { $0.value.eq(value) }
    }
    
    package static func findByIdentity(_ identityId: Identity.ID) -> Where<Identity.Token.Record> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    package static func findByType(_ type: TokenType) -> Where<Identity.Token.Record> {
        Self.where { $0.type.eq(type) }
    }
    
    package static func findByIdentityAndType(_ identityId: Identity.ID, _ type: TokenType) -> Where<Identity.Token.Record> {
        Self.where { 
            $0.identityId.eq(identityId)
                .and($0.type.eq(type))
        }
    }
    
    package static var valid: Where<Identity.Token.Record> {
        Self.where { token in
            token.validUntil > Date()
        }
    }
    
    package static var expired: Where<Identity.Token.Record> {
        Self.where { token in
            token.validUntil <= Date()
        }
    }
    
    package static func findValid(value: String, type: TokenType) -> Where<Identity.Token.Record> {
        Self.where { token in
            token.value.eq(value)
                .and(token.type.eq(type))
                .and(token.validUntil > Date())
        }
    }
}

// MARK: - Token Type Extensions

extension Identity.Token.Record.TokenType {
    package static let emailVerification: Self = "email_verification"
    package static let passwordReset: Self = "password_reset"
    package static let emailChange: Self = "email_change"
    package static let accountDeletion: Self = "account_deletion"
    package static let apiAccess: Self = "api_access"
    package static let mfaSession: Self = "mfa_session"
    package static let reauthorization: Self = "reauthorization"
    package static let reauthentication: Self = "reauthentication"
}

// MARK: - Validation & Usage

extension Identity.Token.Record {
    package var isValid: Bool {
        @Dependency(\.date) var date
        return validUntil > date()
    }
    
    package var isExpired: Bool {
        @Dependency(\.date) var date
        return validUntil <= date()
    }
    
    package mutating func markAsUsed() {
        @Dependency(\.date) var date
        self.lastUsedAt = date()
    }
}

extension Identity.Token.Record {
    
    /// Validate token and get associated identity in single query
    /// Replaces: findValid + separate identity lookup
    package static func validateWithIdentity(value: String, type: TokenType) async throws -> TokenWithIdentity? {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Identity.Token.Record
                .where { token in
                    token.value.eq(value)
                        .and(token.type.eq(type))
                        .and(token.validUntil > Date())
                }
                .join(Identity.Record.all) { token, identity in
                    token.identityId.eq(identity.id)
                }
                .select { token, identity in
                    TokenWithIdentity.Columns(
                        token: token,
                        identity: identity
                    )
                }
                .fetchOne(db)
        }
    }
    
    /// Batch cleanup expired tokens with count
    package static func cleanupExpiredWithCount() async throws -> Int {
        @Dependency(\.defaultDatabase) var db
        
        // First get count of expired tokens
        let count = try await db.read { db in
            try await Identity.Token.Record
                .where { token in
                    token.validUntil <= Date()
                }
                .fetchCount(db)
        }
        
        // Then delete them
        if count > 0 {
            try await db.write { db in
                try await Identity.Token.Record
                    .delete()
                    .where { token in
                        token.validUntil <= Date()
                    }
                    .execute(db)
            }
        }
        
        return count
    }
}

@Selection
package struct TokenWithIdentity: Sendable {
    package let token: Identity.Token.Record
    package let identity: Identity.Record
}
