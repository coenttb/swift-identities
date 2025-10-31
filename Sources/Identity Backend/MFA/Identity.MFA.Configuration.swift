//
//  Identity.MFA.Configuration.swift
//  swift-identities
//
//  Composite configuration for all MFA methods
//

import Foundation
import IdentitiesTypes

extension Identity.MFA {
  /// Composite configuration containing all MFA method configurations
  public struct Configuration: Sendable {
    /// TOTP configuration (authenticator apps)
    public var totp: Identity.MFA.TOTP.Configuration?

    /// SMS configuration
    public var sms: Identity.MFA.SMS.Configuration?

    /// Email MFA configuration (separate from account emails)
    public var email: Identity.MFA.Email.Configuration?

    /// WebAuthn configuration (security keys)
    public var webauthn: Identity.MFA.WebAuthn.Configuration?

    /// Backup codes configuration
    public var backupCodes: Identity.MFA.BackupCodes.Configuration?

    // MARK: - Shared Settings

    /// Maximum number of verification attempts before lockout
    public var maxVerificationAttempts: Int

    /// Duration of lockout period in seconds
    public var lockoutDurationSeconds: Int

    /// Whether to require MFA for all users
    public var requireForAllUsers: Bool

    /// Grace period for new accounts before MFA is required (in seconds)
    public var gracePeriodSeconds: Int?

    public init(
      totp: Identity.MFA.TOTP.Configuration? = nil,
      sms: Identity.MFA.SMS.Configuration? = nil,
      email: Identity.MFA.Email.Configuration? = nil,
      webauthn: Identity.MFA.WebAuthn.Configuration? = nil,
      backupCodes: Identity.MFA.BackupCodes.Configuration? = nil,
      maxVerificationAttempts: Int = 3,
      lockoutDurationSeconds: Int = 900,  // 15 minutes
      requireForAllUsers: Bool = false,
      gracePeriodSeconds: Int? = nil
    ) {
      self.totp = totp
      self.sms = sms
      self.email = email
      self.webauthn = webauthn
      self.backupCodes = backupCodes
      self.maxVerificationAttempts = maxVerificationAttempts
      self.lockoutDurationSeconds = lockoutDurationSeconds
      self.requireForAllUsers = requireForAllUsers
      self.gracePeriodSeconds = gracePeriodSeconds
    }
  }
}

// MARK: - Convenience Configurations

extension Identity.MFA.Configuration {
  /// Basic MFA with just TOTP
  public static func basic(issuer: String) -> Self {
    Self(
      totp: .standard(issuer: issuer),
      backupCodes: .standard
    )
  }

  /// Full MFA with all methods except WebAuthn
  public static func full(
    issuer: String,
    sendSMS: @escaping @Sendable (String, String) async throws -> Void,
    sendEmail: @escaping @Sendable (EmailAddress, String) async throws -> Void
  ) -> Self {
    Self(
      totp: .standard(issuer: issuer),
      sms: .init(sendCode: sendSMS),
      email: .init(sendCode: sendEmail),
      backupCodes: .standard,
      requireForAllUsers: false,
      gracePeriodSeconds: 7 * 24 * 60 * 60  // 7 days
    )
  }

  /// Security-focused configuration
  public static func secure(
    issuer: String,
    webauthnConfig: Identity.MFA.WebAuthn.Configuration
  ) -> Self {
    Self(
      totp: .secure(issuer: issuer),
      webauthn: webauthnConfig,
      backupCodes: .secure,
      maxVerificationAttempts: 3,
      lockoutDurationSeconds: 1800,  // 30 minutes
      requireForAllUsers: true
    )
  }

  /// Test configuration
  public static var test: Self {
    Self(
      totp: .test,
      sms: .test,
      email: .test,
      webauthn: .test,
      backupCodes: .test,
      maxVerificationAttempts: 5,
      lockoutDurationSeconds: 60,
      requireForAllUsers: false
    )
  }

  /// No-op configuration (MFA disabled)
  public static var noop: Self {
    Self()
  }
}

// MARK: - Computed Properties

extension Identity.MFA.Configuration {
  /// Check if any MFA method is configured
  public var isEnabled: Bool {
    totp != nil || sms != nil || email != nil || webauthn != nil
  }

  /// Get all enabled MFA methods
  public var enabledMethods: Set<Identity.MFA.Method> {
    var methods = Set<Identity.MFA.Method>()
    if totp != nil { methods.insert(.totp) }
    if sms != nil { methods.insert(.sms) }
    if email != nil { methods.insert(.email) }
    if webauthn != nil { methods.insert(.webauthn) }
    if backupCodes != nil { methods.insert(.backupCode) }
    return methods
  }
}

extension Identity.MFA {
  package init(from config: Identity.MFA.Configuration) {
    self.init(
      totp: config.totp.map { totpConfig in
        Identity.MFA.TOTP(
          client: .live(configuration: totpConfig),
          router: Identity.MFA.TOTP.API.Router()
        )
      }
        ?? Identity.MFA.TOTP(
          client: Identity.MFA.TOTP.Client(),  // Default/empty initializer
          router: Identity.MFA.TOTP.API.Router()
        ),
      sms: config.sms.map { smsConfig in
        Identity.MFA.SMS(
          client: Identity.MFA.SMS.Client(),  // TODO: Add .live(configuration:) when implemented
          router: Identity.MFA.SMS.API.Router()
        )
      }
        ?? Identity.MFA.SMS(
          client: Identity.MFA.SMS.Client(),  // Default/empty initializer
          router: Identity.MFA.SMS.API.Router()
        ),
      email: config.email.map { emailConfig in
        Identity.MFA.Email(
          client: Identity.MFA.Email.Client(),  // TODO: Add .live(configuration:) when implemented
          router: Identity.MFA.Email.API.Router()
        )
      }
        ?? Identity.MFA.Email(
          client: Identity.MFA.Email.Client(),  // Default/empty initializer
          router: Identity.MFA.Email.API.Router()
        ),
      webauthn: config.webauthn.map { webauthnConfig in
        Identity.MFA.WebAuthn(
          client: Identity.MFA.WebAuthn.Client(),  // TODO: Add .live(configuration:) when implemented
          router: Identity.MFA.WebAuthn.API.Router()
        )
      }
        ?? Identity.MFA.WebAuthn(
          client: Identity.MFA.WebAuthn.Client(),  // Default/empty initializer
          router: Identity.MFA.WebAuthn.API.Router()
        ),
      backupCodes: config.backupCodes.map { backupConfig in
        Identity.MFA.BackupCodes(
          client: Identity.MFA.BackupCodes.Client(),  // TODO: Add .live(configuration:) when implemented
          router: Identity.MFA.BackupCodes.API.Router()
        )
      }
        ?? Identity.MFA.BackupCodes(
          client: Identity.MFA.BackupCodes.Client(),  // Default/empty initializer
          router: Identity.MFA.BackupCodes.API.Router()
        ),
      status: Identity.MFA.Status(
        client: .live(),
        router: Identity.MFA.Status.API.Router()
      ),
      router: Identity.MFA.Route.Router()
    )
  }
}
