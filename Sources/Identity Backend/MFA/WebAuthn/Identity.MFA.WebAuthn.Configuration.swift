//
//  Identity.MFA.WebAuthn.Configuration.swift
//  swift-identities
//
//  WebAuthn configuration for multi-factor authentication
//

import Foundation
import IdentitiesTypes

extension Identity.MFA.WebAuthn {
  /// Configuration for WebAuthn-based multi-factor authentication (security keys)
  public struct Configuration: Sendable {
    /// The relying party identifier (typically the domain)
    public var relyingPartyID: String

    /// The display name for the relying party
    public var relyingPartyName: String

    /// The origin where WebAuthn operations are performed
    public var relyingPartyOrigin: String

    /// Allowed authenticator attachment types
    public var authenticatorAttachment: AuthenticatorAttachment?

    /// User verification requirement
    public var userVerification: UserVerification

    /// Timeout for operations in milliseconds
    public var timeout: Int?

    public enum AuthenticatorAttachment: String, Codable, Sendable {
      case platform  // Built-in authenticator like Touch ID
      case crossPlatform  // External authenticator like YubiKey
    }

    public enum UserVerification: String, Codable, Sendable {
      case required
      case preferred
      case discouraged
    }

    public init(
      relyingPartyID: String,
      relyingPartyName: String,
      relyingPartyOrigin: String,
      authenticatorAttachment: AuthenticatorAttachment? = nil,
      userVerification: UserVerification = .preferred,
      timeout: Int? = 60000
    ) {
      self.relyingPartyID = relyingPartyID
      self.relyingPartyName = relyingPartyName
      self.relyingPartyOrigin = relyingPartyOrigin
      self.authenticatorAttachment = authenticatorAttachment
      self.userVerification = userVerification
      self.timeout = timeout
    }

    /// Test configuration
    public static var test: Self {
      Self(
        relyingPartyID: "localhost",
        relyingPartyName: "Test Application",
        relyingPartyOrigin: "http://localhost:8080",
        userVerification: .discouraged,
        timeout: 30000
      )
    }
  }
}
