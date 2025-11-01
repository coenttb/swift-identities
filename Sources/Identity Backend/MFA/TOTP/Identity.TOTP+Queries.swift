import Crypto
import Dependencies
import Foundation
import RFC_6238
import Records
import TOTP

// MARK: - Helper Functions

extension Identity.MFA.TOTP.Record {
  /// Encrypt the secret for storage using AES-GCM
  package static func encryptSecret(_ secret: String) throws -> String {
    @Dependency(\.envVars.encryptionKey) var encryptionKey
    @Dependency(\.logger) var logger

    // If no encryption key is set, store as-is (development mode)
    guard !encryptionKey.isEmpty else {
      logger.warning(
        "TOTP secrets stored without encryption - set IDENTITIES_ENCRYPTION_KEY in production",
        metadata: [
          "component": "Identity.MFA.TOTP",
          "mode": "development",
        ]
      )
      return secret
    }

    // Use proper AES-GCM encryption (same pattern as OAuth)
    let keyData = SHA256.hash(data: Data(encryptionKey.utf8))
    let key = SymmetricKey(data: keyData)
    let data = Data(secret.utf8)
    let sealedBox = try AES.GCM.seal(data, using: key)

    // Prefix with "v1:" for version tracking
    guard let combined = sealedBox.combined else {
      throw TOTPError.encryptionFailed
    }
    return "v1:" + combined.base64EncodedString()
  }

  /// Decrypt the secret for use
  package func decryptedSecret() throws -> String {
    @Dependency(\.envVars.encryptionKey) var encryptionKey
    @Dependency(\.logger) var logger

    // Empty secret
    if self.secret.isEmpty {
      return self.secret
    }

    // Check if unencrypted (development mode or legacy)
    if encryptionKey.isEmpty {
      if self.secret.hasPrefix("v1:") {
        logger.error(
          "Found encrypted TOTP secret but no encryption key set",
          metadata: [
            "component": "Identity.MFA.TOTP"
          ]
        )
        throw TOTPError.encryptionKeyMissing
      }
      return self.secret
    }

    // Check if encrypted with v1 format (AES-GCM)
    if self.secret.hasPrefix("v1:") {
      // Remove version prefix and decrypt
      let encryptedData = String(self.secret.dropFirst(3))
      guard let data = Data(base64Encoded: encryptedData) else {
        logger.error(
          "Failed to decode base64 TOTP secret data",
          metadata: [
            "component": "Identity.MFA.TOTP"
          ]
        )
        throw TOTPError.invalidFormat
      }

      let keyData = SHA256.hash(data: Data(encryptionKey.utf8))
      let key = SymmetricKey(data: keyData)

      do {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: key)

        guard let secret = String(data: decrypted, encoding: .utf8) else {
          throw TOTPError.decryptionFailed
        }

        return secret
      } catch {
        logger.error(
          "Failed to decrypt TOTP secret",
          metadata: [
            "component": "Identity.MFA.TOTP",
            "error": "\(error)",
          ]
        )
        throw TOTPError.decryptionFailed
      }
    }

    // Handle legacy Base64-encoded format (migration path)
    // Check if it has old encryption prefix
    if let data = Data(base64Encoded: self.secret),
      let decoded = String(data: data, encoding: .utf8)
    {
      if decoded.hasPrefix("\(encryptionKey):") {
        logger.debug(
          "Migrating legacy encrypted TOTP secret",
          metadata: [
            "component": "Identity.MFA.TOTP"
          ]
        )
        return String(decoded.dropFirst(encryptionKey.count + 1))
      }
    }

    // Plain Base32 secret (unencrypted - backward compatibility)
    logger.debug(
      "Using unencrypted TOTP secret",
      metadata: [
        "component": "Identity.MFA.TOTP"
      ]
    )
    return self.secret
  }

  enum TOTPError: Swift.Error {
    case invalidSecret
    case alreadyExists
    case encryptionKeyMissing
    case encryptionFailed
    case invalidFormat
    case decryptionFailed
  }
}
