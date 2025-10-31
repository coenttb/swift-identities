//
//  Identity.Backend.Configuration.swift
//  swift-identities
//
//  Backend configuration structure
//

import Dependencies
import Foundation
import IdentitiesTypes
import Identity_Shared
import URLRouting

extension Identity.Backend {
  /// Backend configuration containing all necessary services and callbacks
  public struct Configuration: @unchecked Sendable {
    /// JWT token client for generating and verifying tokens
    public var jwt: Identity.Token.Client

    /// Router for generating authentication URLs
    //        public var router: Identity.Authentication.Route.Router
    public var router: any URLRouting.Router<Identity.Authentication.Route>

    /// Email configuration with all email callbacks
    public var email: Identity.Backend.Configuration.Email

    /// Token enrichment for adding custom JWT claims
    public var tokenEnrichment: Identity.Backend.Configuration.TokenEnrichment?

    /// MFA configuration
    public var mfa: Identity.MFA?

    /// OAuth configuration
    public var oauth: Identity.OAuth?

    public init(
      jwt: Identity.Token.Client,
      router: any URLRouting.Router<Identity.Authentication.Route>,
      email: Identity.Backend.Configuration.Email,
      tokenEnrichment: Identity.Backend.Configuration.TokenEnrichment? = nil,
      mfa: Identity.MFA? = nil,
      oauth: Identity.OAuth? = nil
    ) {
      self.jwt = jwt
      self.router = router
      self.email = email
      self.tokenEnrichment = tokenEnrichment
      self.mfa = mfa
      self.oauth = oauth
    }
  }
}

// MARK: - Email Configuration

extension Identity.Backend.Configuration {
  /// Email configuration containing all email-related callbacks
  public struct Email: Sendable {
    public var sendVerificationEmail: @Sendable (EmailAddress, String) async throws -> Void
    public var sendPasswordResetEmail: @Sendable (EmailAddress, String) async throws -> Void
    public var sendPasswordChangeNotification: @Sendable (EmailAddress) async throws -> Void
    public var sendEmailChangeConfirmation:
      @Sendable (EmailAddress, EmailAddress, String) async throws -> Void
    public var sendEmailChangeRequestNotification:
      @Sendable (EmailAddress, EmailAddress) async throws -> Void
    public var onEmailChangeSuccess: @Sendable (EmailAddress, EmailAddress) async throws -> Void
    public var sendDeletionRequestNotification: @Sendable (EmailAddress) async throws -> Void
    public var sendDeletionConfirmationNotification: @Sendable (EmailAddress) async throws -> Void
    public var onIdentityCreationSuccess:
      @Sendable ((id: Identity.ID, email: EmailAddress)) async throws -> Void

    public init(
      sendVerificationEmail: @escaping @Sendable (EmailAddress, String) async throws -> Void,
      sendPasswordResetEmail: @escaping @Sendable (EmailAddress, String) async throws -> Void,
      sendPasswordChangeNotification: @escaping @Sendable (EmailAddress) async throws -> Void,
      sendEmailChangeConfirmation: @escaping @Sendable (EmailAddress, EmailAddress, String)
        async throws -> Void,
      sendEmailChangeRequestNotification: @escaping @Sendable (EmailAddress, EmailAddress)
        async throws -> Void,
      onEmailChangeSuccess: @escaping @Sendable (EmailAddress, EmailAddress) async throws -> Void,
      sendDeletionRequestNotification: @escaping @Sendable (EmailAddress) async throws -> Void,
      sendDeletionConfirmationNotification: @escaping @Sendable (EmailAddress) async throws -> Void,
      onIdentityCreationSuccess: @escaping @Sendable ((id: Identity.ID, email: EmailAddress))
        async throws -> Void = { _ in }
    ) {
      self.sendVerificationEmail = sendVerificationEmail
      self.sendPasswordResetEmail = sendPasswordResetEmail
      self.sendPasswordChangeNotification = sendPasswordChangeNotification
      self.sendEmailChangeConfirmation = sendEmailChangeConfirmation
      self.sendEmailChangeRequestNotification = sendEmailChangeRequestNotification
      self.onEmailChangeSuccess = onEmailChangeSuccess
      self.sendDeletionRequestNotification = sendDeletionRequestNotification
      self.sendDeletionConfirmationNotification = sendDeletionConfirmationNotification
      self.onIdentityCreationSuccess = onIdentityCreationSuccess
    }

    /// Creates a no-op email configuration for testing
    public static var noop: Self {
      Self(
        sendVerificationEmail: { _, _ in },
        sendPasswordResetEmail: { _, _ in },
        sendPasswordChangeNotification: { _ in },
        sendEmailChangeConfirmation: { _, _, _ in },
        sendEmailChangeRequestNotification: { _, _ in },
        onEmailChangeSuccess: { _, _ in },
        sendDeletionRequestNotification: { _ in },
        sendDeletionConfirmationNotification: { _ in },
        onIdentityCreationSuccess: { _ in }
      )
    }
  }
}

// MARK: - Token Enrichment

extension Identity.Backend.Configuration {
  /// Token enrichment configuration for adding custom claims to JWT tokens
  public struct TokenEnrichment: Sendable {
    /// Closure to provide additional claims for a given identity
    public var additionalClaims: @Sendable (Identity.ID) async throws -> [String: Any]

    public init(
      additionalClaims: @escaping @Sendable (Identity.ID) async throws -> [String: Any]
    ) {
      self.additionalClaims = additionalClaims
    }
  }
}

// MARK: - Test Configuration

extension Identity.Backend.Configuration: TestDependencyKey {
  public static var testValue: Self {
    Self(
      jwt: .test(),
      router: Identity.Authentication.Route.Router(),
      email: .noop,
      tokenEnrichment: nil,
      mfa: nil,
      oauth: nil
    )
  }
}
