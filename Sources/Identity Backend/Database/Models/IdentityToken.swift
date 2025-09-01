import Foundation
import Records
import Dependencies
import Crypto

extension Database.Identity {
    @Table("identity_tokens")
    package struct Token: Codable, Equatable, Identifiable, Sendable {
        package let id: UUID
        package var value: String
        package var validUntil: Date
        package var identityId: UUID
        package var type: TokenType
        package var createdAt: Date = Date()
        package var lastUsedAt: Date?
        
        package struct TokenType: RawRepresentable, Codable, Hashable, QueryBindable, Sendable, ExpressibleByStringLiteral {
            package let rawValue: String
            
            package init(rawValue: String) {
                self.rawValue = rawValue
            }
            
            package init(stringLiteral value: StringLiteralType) {
                self = .init(rawValue: value)
            }
        }
        
        package init(
            id: UUID,
            value: String,
            validUntil: Date,
            identityId: UUID,
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
            identityId: UUID,
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

extension Database.Identity.Token {
    package static func findByValue(_ value: String) -> Where<Database.Identity.Token> {
        Self.where { $0.value.eq(value) }
    }
    
    package static func findByIdentity(_ identityId: UUID) -> Where<Database.Identity.Token> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    package static func findByType(_ type: TokenType) -> Where<Database.Identity.Token> {
        Self.where { $0.type.eq(type) }
    }
    
    package static var valid: Where<Database.Identity.Token> {
        Self.where { token in
            #sql("\(token.validUntil) > CURRENT_TIMESTAMP")
        }
    }
    
    package static var expired: Where<Database.Identity.Token> {
        Self.where { token in
            #sql("\(token.validUntil) <= CURRENT_TIMESTAMP")
        }
    }
    
    package static func validTokenOfType(_ type: TokenType) -> Where<Database.Identity.Token> {
        Self.where { token in
            token.type.eq(type) && #sql("\(token.validUntil) > CURRENT_TIMESTAMP")
        }
    }
}

extension Database.Identity.Token.TokenType {
    static let emailVerification: Self = "email-verification"
    static let passwordReset: Self = "password-reset"
    static let accountActivation: Self = "account-activation"
    static let twoFactorAuthentication: Self = "two-factor-authentication"
    static let apiAccess: Self = "api-access"
    static let refreshToken: Self = "refresh-token"
    static let sessionToken: Self = "session-token"
    static let rememberMeToken: Self = "remember-me-token"
    static let invitationToken: Self = "invitation-token"
    static let passwordlessLogin: Self = "passwordless-login"
    static let accountDeletion: Self = "account-deletion"
    static let emailChange: Self = "email-change"
    static let phoneNumberVerification: Self = "phone-number-verification"
    static let termsAcceptance: Self = "terms-acceptance"
    static let consentToken: Self = "consent-token"
    static let temporaryAccess: Self = "temporary-access"
    static let reauthenticationToken: Self = "reauthentication-token"
}

// MARK: - Token Validation

extension Database.Identity.Token {
    package var isValid: Bool {
        @Dependency(\.date) var date
        return validUntil > date()
    }
    
    package var isExpired: Bool {
        !isValid
    }
    
    package mutating func markAsUsed() {
        @Dependency(\.date) var date
        self.lastUsedAt = date()
    }
}
