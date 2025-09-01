import Dependencies
import EmailAddress
import Foundation
import JWT
import ServerFoundation

extension Identity.Token {
    /// Access token for short-lived authentication
    public struct Access: Sendable {
        /// The underlying JWT token
        public let jwt: JWT
        
        /// The identity ID extracted from the subject claim
        public var identityId: UUID {
            guard let sub = jwt.payload.sub,
                  let components = Self.parseSubject(sub),
                  let id = UUID(uuidString: components.id) else {
                fatalError()
            }
            return id
        }
        
        /// The email address extracted from the subject claim
        public var email: EmailAddress {
            guard let sub = jwt.payload.sub,
                  let components = Self.parseSubject(sub) else {
                fatalError()
            }
            return try! .init(components.email)
        }
        
        /// The display name (only available in Standalone deployments)
        public var displayName: String {
            jwt.payload.additionalClaim("displayName", as: String.self) ?? "User"
        }
        
        /// Session version for token invalidation
        public var sessionVersion: Int {
            jwt.payload.additionalClaim("sev", as: Int.self) ?? 0
        }
        
        /// Check if the token is expired
        public var isExpired: Bool {
            if let exp = jwt.payload.exp {
                return Date() > exp
            }
            return false
        }
        
        /// Get the time remaining until expiry (in seconds)
        public var timeUntilExpiry: TimeInterval? {
            guard let exp = jwt.payload.exp else { return nil }
            return exp.timeIntervalSinceNow
        }
        
        /// Check if token should be refreshed (less than 5 minutes remaining)
        public var shouldRefresh: Bool {
            guard let timeRemaining = timeUntilExpiry else { return false }
            return timeRemaining < 300 // 5 minutes
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
        
        /// Creates a new access token
        public init(
            identityId: UUID,
            email: EmailAddress,
            sessionVersion: Int,
            issuer: String,
            expiresIn: TimeInterval,
            signingKey: SigningKey,
            additionalClaims: [String: Any] = [:] // For Standalone to add displayName
        ) throws {
            // Create subject in format "id:email"
            let subject = "\(identityId.uuidString):\(email.rawValue)"
            
            var claims: [String: Any] = [
                "sev": sessionVersion,
                "type": "access"
            ]
            
            // Add any additional claims (like displayName for Standalone)
            for (key, value) in additionalClaims {
                claims[key] = value
            }
            
            self.jwt = try JWT.signed(
                algorithm: .hmacSHA256,
                key: signingKey,
                issuer: issuer,
                subject: subject,
                expiresIn: expiresIn,
                claims: claims
            )
        }
        
        /// Creates an access token from an existing JWT
        public init(jwt: JWT) throws {
            // Validate it's an access token
            guard jwt.payload.additionalClaim("type", as: String.self) == "access" else {
                throw TokenError.invalidTokenType
            }
            
            // Validate subject format
            guard let subject = jwt.payload.sub,
                  Self.parseSubject(subject) != nil else {
                throw TokenError.invalidSubjectFormat
            }
            
            self.jwt = jwt
        }
        
        /// Parse subject string "id:email" into components
        private static func parseSubject(_ subject: String) -> (id: String, email: String)? {
            let components = subject.split(separator: ":", maxSplits: 1).map(String.init)
            guard components.count == 2 else { return nil }
            return (components[0], components[1])
        }
    }
}

// MARK: - Token Verification

extension Identity.Token.Access {
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

extension Identity.Token.Access {
    public enum TokenError: Swift.Error {
        case invalidTokenType
        case invalidSubjectFormat
        case verificationFailed
    }
}
