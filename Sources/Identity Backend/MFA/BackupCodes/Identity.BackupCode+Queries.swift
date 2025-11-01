import Crypto
import Dependencies
import Foundation
import Records

// MARK: - Database Operations

extension Identity.MFA.BackupCodes.Record {

  // REMOVED: findById() - Use explicit queries at call sites
  // REMOVED: findUnusedByIdentity() - Use explicit queries at call sites
  // REMOVED: countUnusedByIdentity() - Use explicit queries at call sites
  // REMOVED: create() that auto-saves - Create records inline within transactions
  // REMOVED: verify() - Implement verification inline with proper transaction
  // REMOVED: markAsUsed() - Make DB updates explicit at call sites
  // REMOVED: deleteForIdentity() - Make DB deletes explicit at call sites
}

// MARK: - Helper Functions

extension Identity.MFA.BackupCodes.Record {
  /// Hash a backup code for storage
  package static func hashCode(_ code: String) async throws -> String {
    @Dependency(\.passwordHasher) var passwordHasher
    @Dependency(\.envVars) var envVars

    // Use password hasher like passwords for secure hashing
    return try await passwordHasher.hash(code, envVars.bcryptCost)
  }

  /// Verify a code against its hash
  package static func verifyCode(_ code: String, hash: String) async throws -> Bool {
    @Dependency(\.passwordHasher) var passwordHasher
    return try await passwordHasher.verify(code, hash)
  }

  /// Generate a random backup code
  package static func generateCode(length: Int = 8) -> String {
    let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var code = ""
    for _ in 0..<length {
      let randomIndex = Int.random(in: 0..<characters.count)
      let index = characters.index(characters.startIndex, offsetBy: randomIndex)
      code += String(characters[index])
    }
    return code
  }
}
