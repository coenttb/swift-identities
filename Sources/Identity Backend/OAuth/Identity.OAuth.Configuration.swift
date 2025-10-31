//
//  Identity.OAuth.Configuration.swift
//  swift-identities
//
//  OAuth configuration for third-party authentication providers
//

import Foundation
import IdentitiesTypes

extension Identity.OAuth {
  /// Configuration for OAuth authentication providers
  public struct Configuration: Sendable {
    /// Registered OAuth providers
    public var providers: [any Identity.OAuth.Provider]

    /// Whether to store OAuth tokens for API access
    /// If false, tokens are only used for authentication and discarded
    public var storeTokens: Bool

    /// Encryption key for stored tokens (required if storeTokens is true)
    public var tokenEncryptionKey: String?

    /// Path to redirect after successful OAuth authentication
    public var successRedirectPath: String

    /// Path to redirect after failed OAuth authentication
    public var failureRedirectPath: String

    /// How long OAuth state tokens remain valid (in seconds)
    public var stateExpirationSeconds: Int

    /// Whether to automatically create accounts for new OAuth users
    public var autoCreateAccounts: Bool

    /// Whether to allow linking OAuth accounts to existing identities
    public var allowAccountLinking: Bool

    // MARK: - Callbacks

    /// Called after successful OAuth authentication
    public var onOAuthSuccess: (@Sendable (Identity.OAuth.UserInfo) async throws -> Void)?

    /// Called when linking OAuth account to existing identity
    public var onOAuthLink:
      (@Sendable (Identity.ID, Identity.OAuth.Connection) async throws -> Void)?

    /// Called when OAuth authentication fails
    public var onOAuthFailure: (@Sendable (Error) async throws -> Void)?

    public init(
      providers: [any Identity.OAuth.Provider] = [],
      storeTokens: Bool = false,
      tokenEncryptionKey: String? = nil,
      successRedirectPath: String = "/",
      failureRedirectPath: String = "/login",
      stateExpirationSeconds: Int = 600,  // 10 minutes
      autoCreateAccounts: Bool = true,
      allowAccountLinking: Bool = true,
      onOAuthSuccess: (@Sendable (Identity.OAuth.UserInfo) async throws -> Void)? = nil,
      onOAuthLink: (@Sendable (Identity.ID, Identity.OAuth.Connection) async throws -> Void)? = nil,
      onOAuthFailure: (@Sendable (Error) async throws -> Void)? = nil
    ) {
      self.providers = providers
      self.storeTokens = storeTokens
      self.tokenEncryptionKey = tokenEncryptionKey
      self.successRedirectPath = successRedirectPath
      self.failureRedirectPath = failureRedirectPath
      self.stateExpirationSeconds = stateExpirationSeconds
      self.autoCreateAccounts = autoCreateAccounts
      self.allowAccountLinking = allowAccountLinking
      self.onOAuthSuccess = onOAuthSuccess
      self.onOAuthLink = onOAuthLink
      self.onOAuthFailure = onOAuthFailure
    }
  }
}

// MARK: - Convenience Configurations

extension Identity.OAuth.Configuration {
  /// Basic OAuth configuration with common providers
  public static func basic(
    providers: [any Identity.OAuth.Provider],
    successPath: String = "/dashboard",
    failurePath: String = "/login"
  ) -> Self {
    Self(
      providers: providers,
      storeTokens: false,
      successRedirectPath: successPath,
      failureRedirectPath: failurePath,
      autoCreateAccounts: true,
      allowAccountLinking: true
    )
  }

  /// Configuration for API-focused OAuth (stores tokens)
  public static func api(
    providers: [any Identity.OAuth.Provider],
    tokenEncryptionKey: String
  ) -> Self {
    Self(
      providers: providers,
      storeTokens: true,
      tokenEncryptionKey: tokenEncryptionKey,
      successRedirectPath: "/dashboard",
      failureRedirectPath: "/login",
      autoCreateAccounts: true,
      allowAccountLinking: true
    )
  }

  /// Strict configuration that requires existing accounts
  public static func strict(
    providers: [any Identity.OAuth.Provider]
  ) -> Self {
    Self(
      providers: providers,
      storeTokens: false,
      successRedirectPath: "/dashboard",
      failureRedirectPath: "/login",
      autoCreateAccounts: false,
      allowAccountLinking: false
    )
  }

  /// Test configuration
  public static var test: Self {
    Self(
      providers: [],
      storeTokens: false,
      successRedirectPath: "/test/success",
      failureRedirectPath: "/test/failure",
      stateExpirationSeconds: 60,
      autoCreateAccounts: true,
      allowAccountLinking: true
    )
  }

  /// No-op configuration (OAuth disabled)
  public static var noop: Self {
    Self(providers: [])
  }
}

// MARK: - Computed Properties

extension Identity.OAuth.Configuration {
  /// Check if OAuth is enabled
  public var isEnabled: Bool {
    !providers.isEmpty
  }

  /// Get provider by identifier
  public func provider(for identifier: String) -> (any Identity.OAuth.Provider)? {
    providers.first { $0.identifier == identifier }
  }

  /// Get all provider identifiers
  public var providerIdentifiers: [String] {
    providers.map { $0.identifier }
  }

  /// Validate configuration
  public func validate() throws {
    if storeTokens && tokenEncryptionKey == nil {
      throw ConfigurationError.missingEncryptionKey
    }

    if storeTokens, let key = tokenEncryptionKey, key.count < 32 {
      throw ConfigurationError.weakEncryptionKey
    }
  }

  public enum ConfigurationError: Error, LocalizedError {
    case missingEncryptionKey
    case weakEncryptionKey

    public var errorDescription: String? {
      switch self {
      case .missingEncryptionKey:
        return "Token encryption key is required when storeTokens is enabled"
      case .weakEncryptionKey:
        return "Token encryption key must be at least 32 characters"
      }
    }
  }
}

extension Identity.OAuth {
  package init(from config: Identity.OAuth.Configuration) {
    self.init(
      client: .live(configuration: config),
      router: Identity.OAuth.Route.Router()
    )
  }
}
