//
//  Identity.MFA.TOTP.Configuration.swift
//  swift-identities
//
//  TOTP configuration for multi-factor authentication
//

import Foundation
import IdentitiesTypes
import RFC_6238
import TOTP

extension Identity.MFA.TOTP {
  /// Configuration for TOTP (Time-based One-Time Password) authentication
  public struct Configuration: Sendable {
    /// The issuer name displayed in authenticator apps
    public let issuer: String

    /// The hashing algorithm to use for TOTP generation
    public let algorithm: Algorithm

    /// The number of digits in the generated codes
    public let digits: Int

    /// The time period in seconds for which a code is valid
    public let timeStep: TimeInterval

    /// The verification window (in periods) to allow for clock skew
    /// A window of 1 means codes from 1 period before/after are also valid
    public let verificationWindow: Int

    /// The length of backup codes
    public let backupCodeLength: Int

    /// The number of backup codes to generate
    public let backupCodeCount: Int

    /// Optional: Size of the QR code image in pixels
    public let qrCodeSize: Int?

    /// Type alias for algorithm from RFC_6238
    public typealias Algorithm = RFC_6238.TOTP.Algorithm

    public init(
      issuer: String,
      algorithm: Algorithm = .sha1,
      digits: Int = 6,
      timeStep: TimeInterval = 30,
      verificationWindow: Int = 1,
      backupCodeLength: Int = 8,
      backupCodeCount: Int = 10,
      qrCodeSize: Int? = 200
    ) throws {
      // Validation
      guard !issuer.isEmpty else {
        throw ConfigurationError.invalidIssuer("Issuer cannot be empty")
      }
      guard digits >= 6 && digits <= 8 else {
        throw ConfigurationError.invalidDigits("Digits must be between 6 and 8")
      }
      guard timeStep > 0 && timeStep <= 300 else {
        throw ConfigurationError.invalidTimeStep("Time step must be between 1 and 300 seconds")
      }
      guard verificationWindow >= 0 && verificationWindow <= 10 else {
        throw ConfigurationError.invalidWindow("Verification window must be between 0 and 10")
      }
      guard backupCodeLength >= 6 && backupCodeLength <= 16 else {
        throw ConfigurationError.invalidBackupCodeLength(
          "Backup code length must be between 6 and 16"
        )
      }
      guard backupCodeCount >= 0 && backupCodeCount <= 20 else {
        throw ConfigurationError.invalidBackupCodeCount(
          "Backup code count must be between 0 and 20"
        )
      }

      self.issuer = issuer
      self.algorithm = algorithm
      self.digits = digits
      self.timeStep = timeStep
      self.verificationWindow = verificationWindow
      self.backupCodeLength = backupCodeLength
      self.backupCodeCount = backupCodeCount
      self.qrCodeSize = qrCodeSize
    }

    public enum ConfigurationError: Error, Equatable, LocalizedError {
      case invalidIssuer(String)
      case invalidDigits(String)
      case invalidTimeStep(String)
      case invalidWindow(String)
      case invalidBackupCodeLength(String)
      case invalidBackupCodeCount(String)

      public var errorDescription: String? {
        switch self {
        case .invalidIssuer(let message):
          return message
        case .invalidDigits(let message):
          return message
        case .invalidTimeStep(let message):
          return message
        case .invalidWindow(let message):
          return message
        case .invalidBackupCodeLength(let message):
          return message
        case .invalidBackupCodeCount(let message):
          return message
        }
      }
    }
  }
}

// MARK: - Default Configurations

extension Identity.MFA.TOTP.Configuration {
  /// Standard TOTP configuration compatible with most authenticator apps
  public static func standard(issuer: String) -> Self {
    try! Self(
      issuer: issuer,
      algorithm: .sha1,
      digits: 6,
      timeStep: 30,
      verificationWindow: 1,
      backupCodeLength: 8,
      backupCodeCount: 10,
      qrCodeSize: 200
    )
  }

  /// More secure configuration with SHA256
  public static func secure(issuer: String) -> Self {
    try! Self(
      issuer: issuer,
      algorithm: .sha256,
      digits: 8,
      timeStep: 30,
      verificationWindow: 1,
      backupCodeLength: 10,
      backupCodeCount: 12,
      qrCodeSize: 200
    )
  }

  /// Test configuration with shorter periods
  public static var test: Self {
    try! Self(
      issuer: "Test",
      algorithm: .sha1,
      digits: 6,
      timeStep: 10,  // Shorter period for testing
      verificationWindow: 2,  // More lenient for tests
      backupCodeLength: 6,
      backupCodeCount: 5,
      qrCodeSize: 100
    )
  }
}
