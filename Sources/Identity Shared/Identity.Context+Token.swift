//
//  Identity.Context+Token.swift
//  swift-identities
//
//  Extension to bridge Identity.Context with Token.Access
//

import IdentitiesTypes
import JWT

extension Identity.Context {
  /// Create context from an access token
  public init(token: Identity.Token.Access) {
    self.init(jwt: token.jwt)
  }

  /// Try to get the access token if this context was created from one
  /// Note: This creates a new Token.Access instance from the JWT
  public var accessToken: Identity.Token.Access? {
    try? Identity.Token.Access(jwt: jwt)
  }

  /// Check if a specific additional claim exists
  public func hasAdditionalClaim(_ key: String) -> Bool {
    // Try to get the claim as Any type to check existence
    additionalClaim(key, as: Any.self) != nil
  }
}
