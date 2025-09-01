import Dependencies
import Foundation
import JWT
import ServerFoundation

extension Identity.Token {
    /// Reauthorization token for sensitive operations requiring fresh authentication
    public struct Reauthorization: Sendable {
        /// The underlying JWT token
        public let jwt: JWT
        
        /// The identity ID extracted from the subject claim
        public var identityId: UUID? {
            guard let sub = jwt.payload.sub,
                  let id = UUID(uuidString: sub) else {
                return nil
            }
            return id
        }
        
        /// The purpose of this reauthorization
        public var purpose: String {
            jwt.payload.additionalClaim("purpose", as: String.self) ?? "general"
        }
        
        /// Session version for token invalidation
        public var sessionVersion: Int {
            jwt.payload.additionalClaim("sev", as: Int.self) ?? 0
        }
        
        /// Allowed operations for this reauthorization
        public var allowedOperations: [String] {
            jwt.payload.additionalClaim("ops", as: [String].self) ?? []
        }
        
        /// Check if the token is expired
        public var isExpired: Bool {
            if let exp = jwt.payload.exp {
                return Date() > exp
            }
            return false
        }
        
        /// Check if the token is valid
        public var isValid: Bool {
            do {
                try jwt.payload.validateTiming()
                return true
            } catch {
                return false
            }
        }
        
        /// Creates a new reauthorization token
        public init(
            identityId: UUID,
            sessionVersion: Int,
            purpose: String,
            allowedOperations: [String] = [],
            issuer: String,
            expiresIn: TimeInterval = 300, // 5 minutes default
            signingKey: SigningKey
        ) throws {
            @Dependency(\.uuid) var uuid
            
            // Generate unique token ID
            let tokenId = uuid().uuidString
            
            self.jwt = try JWT.signed(
                algorithm: .hmacSHA256,
                key: signingKey,
                issuer: issuer,
                subject: identityId.uuidString,
                expiresIn: expiresIn,
                jti: tokenId,
                claims: [
                    "sev": sessionVersion,
                    "type": "reauth",
                    "purpose": purpose,
                    "ops": allowedOperations
                ]
            )
        }
        
        /// Creates a reauthorization token from an existing JWT
        public init(jwt: JWT) throws {
            // Validate it's a reauthorization token
            guard jwt.payload.additionalClaim("type", as: String.self) == "reauth" else {
                throw TokenError.invalidTokenType
            }
            
            // Validate subject is a valid identity ID
            guard let subject = jwt.payload.sub,
                  UUID(uuidString: subject) != nil else {
                throw TokenError.invalidSubjectFormat
            }
            
            self.jwt = jwt
        }
        
        /// Check if this token allows a specific operation
        public func allowsOperation(_ operation: String) -> Bool {
            allowedOperations.isEmpty || allowedOperations.contains(operation)
        }
    }
}

// MARK: - Reauthorization Purposes

extension Identity.Token.Reauthorization {
    /// Common reauthorization purposes
    public enum Purpose {
        public static let passwordChange = "password_change"
        public static let emailChange = "email_change"
        public static let accountDeletion = "account_deletion"
        public static let apiKeyCreation = "api_key_creation"
        public static let sensitiveDataAccess = "sensitive_data_access"
        public static let general = "general"
    }
}

// MARK: - Token Verification

extension Identity.Token.Reauthorization {
    /// Verifies the token signature and validity
    public func verify(with key: VerificationKey) throws -> Bool {
        try jwt.verifyAndValidate(with: key)
    }
    
    /// Gets the compact serialization for transmission
    public var token: String {
        get throws {
            try jwt.compactSerialization()
        }
    }
}

// MARK: - Errors

extension Identity.Token.Reauthorization {
    public enum TokenError: Swift.Error {
        case invalidTokenType
        case invalidSubjectFormat
        case verificationFailed
        case operationNotAllowed
    }
}
