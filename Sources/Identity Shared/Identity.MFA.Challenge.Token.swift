import Dependencies
import Foundation
import JWT
import ServerFoundation

extension Identity.MFA.Challenge {
  /// MFA session token for multi-factor authentication flow
  public struct Token: Sendable {
    /// The underlying JWT token
    public let jwt: JWT

    /// The identity ID that needs to complete MFA
    /// - Note: This should never fail for properly created tokens, but returns a sentinel value
    ///         if the token is malformed. For validation, use `init(jwt:)` which properly throws.
    public var identityId: Identity.ID {
      guard let sub = jwt.payload.sub,
        let id = UUID(uuidString: sub)
      else {
        // Return sentinel UUID for invalid tokens
        // This allows the token to fail validation downstream rather than crashing
        return Identity.ID(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
      }
      return Identity.ID(id)
    }

    /// Session version for token invalidation
    public var sessionVersion: Int {
      jwt.payload.additionalClaim("sev", as: Int.self) ?? 0
    }

    /// Number of attempts remaining
    public var attemptsRemaining: Int {
      jwt.payload.additionalClaim("attempts", as: Int.self) ?? 3
    }

    /// Available MFA methods for this session
    public var availableMethods: [Identity.MFA.Method] {
      let methods = jwt.payload.additionalClaim("methods", as: [String].self) ?? []
      return methods.compactMap { Identity.MFA.Method(rawValue: $0) }
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

    /// Creates a new MFA session token
    public init(
      identityId: Identity.ID,
      sessionVersion: Int,
      attemptsRemaining: Int = 3,
      availableMethods: [Identity.MFA.Method] = [.totp],
      issuer: String,
      expiresIn: TimeInterval = 300,  // 5 minutes default
      signingKey: SigningKey
    ) throws {
      let claims: [String: Any] = [
        "type": "mfa_session",
        "sev": sessionVersion,
        "attempts": attemptsRemaining,
        "methods": availableMethods.map { $0.rawValue },
      ]

      self.jwt = try JWT.signed(
        algorithm: .hmacSHA256,
        key: signingKey,
        issuer: issuer,
        subject: identityId.uuidString,
        expiresIn: expiresIn,
        jti: UUID().uuidString,
        claims: claims
      )
    }

    /// Creates an MFA session token from a JWT string
    public init(jwt: JWT) throws {
      // Validate token type
      let type = jwt.payload.additionalClaim("type", as: String.self)
      guard type == "mfa_session" else {
        throw TokenError.invalidTokenType
      }

      self.jwt = jwt
    }

    /// Get the encoded token string
    public var token: String {
      get throws {
        try jwt.compactSerialization()
      }
    }

    /// Verify the token with a verification key
    public func verify(with key: VerificationKey) throws -> Bool {
      try jwt.verifyAndValidate(with: key)
    }
  }
}

// MARK: - Errors

extension Identity.MFA.Challenge.Token {
  public enum TokenError: Swift.Error {
    case invalidTokenType
    case invalidIdentityId
    case missingClaims
  }
}
