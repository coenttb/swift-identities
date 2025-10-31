//
//  Identity.MFA.BackupCodes.Configuration.swift
//  swift-identities
//
//  Backup codes configuration for multi-factor authentication
//

import Foundation
import IdentitiesTypes

extension Identity.MFA.BackupCodes {
  /// Configuration for backup codes used as MFA recovery method
  public struct Configuration: Sendable {
    /// Number of backup codes to generate
    public var codeCount: Int

    /// Length of each backup code
    public var codeLength: Int

    /// Format of the generated codes
    public var codeFormat: CodeFormat

    /// Whether to automatically regenerate when running low
    public var autoRegenerateThreshold: Int?

    public enum CodeFormat: Sendable {
      /// Alphanumeric codes (letters and numbers)
      case alphanumeric

      /// Numeric-only codes
      case numeric

      /// Hyphenated codes split into segments (e.g., XXXX-XXXX-XXXX)
      case hyphenated(segments: Int)

      /// Custom character set
      case custom(characters: String)
    }

    public init(
      codeCount: Int = 10,
      codeLength: Int = 8,
      codeFormat: CodeFormat = .alphanumeric,
      autoRegenerateThreshold: Int? = 2
    ) {
      self.codeCount = codeCount
      self.codeLength = codeLength
      self.codeFormat = codeFormat
      self.autoRegenerateThreshold = autoRegenerateThreshold
    }

    /// Standard configuration
    public static var standard: Self {
      Self(
        codeCount: 10,
        codeLength: 8,
        codeFormat: .alphanumeric,
        autoRegenerateThreshold: 2
      )
    }

    /// More secure configuration with longer codes
    public static var secure: Self {
      Self(
        codeCount: 12,
        codeLength: 12,
        codeFormat: .hyphenated(segments: 3),
        autoRegenerateThreshold: 3
      )
    }

    /// Test configuration with shorter codes
    public static var test: Self {
      Self(
        codeCount: 5,
        codeLength: 6,
        codeFormat: .numeric,
        autoRegenerateThreshold: 1
      )
    }
  }
}
