import Dependencies
import Foundation
import JWT
import ServerFoundation

extension Identity.Token {
    /// Refresh token for long-lived authentication and token renewal
    public struct Refresh: Sendable {
        /// The underlying JWT token
        public let jwt: JWT
        
        /// The identity ID extracted from the subject claim
        public var identityId: UUID {
            guard let sub = jwt.payload.sub,
                  let id = UUID(uuidString: sub) else {
                fatalError()
            }
            return id
        }
        
        /// Session version for token invalidation
        public var sessionVersion: Int {
            jwt.payload.additionalClaim("sev", as: Int.self) ?? 0
        }
        
        /// Unique token ID for tracking and revocation
        public var tokenId: String {
            jwt.payload.jti ?? ""
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
        
        /// Creates a new refresh token
        public init(
            identityId: UUID,
            sessionVersion: Int,
            issuer: String,
            expiresIn: TimeInterval,
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
                    "type": "refresh"
                ]
            )
        }
        
        /// Creates a refresh token from an existing JWT
        public init(jwt: JWT) throws {
            // Validate it's a refresh token
            guard jwt.payload.additionalClaim("type", as: String.self) == "refresh" else {
                throw TokenError.invalidTokenType
            }
            
            // Validate subject is a valid identity ID
            guard let subject = jwt.payload.sub,
                  UUID(uuidString: subject) != nil else {
                throw TokenError.invalidSubjectFormat
            }
            
            // Validate token has an ID
            guard jwt.payload.jti != nil else {
                throw TokenError.missingTokenId
            }
            
            self.jwt = jwt
        }
    }
}

// MARK: - Token Verification

extension Identity.Token.Refresh {
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

extension Identity.Token.Refresh {
    public enum TokenError: Swift.Error {
        case invalidTokenType
        case invalidSubjectFormat
        case missingTokenId
        case verificationFailed
    }
}
