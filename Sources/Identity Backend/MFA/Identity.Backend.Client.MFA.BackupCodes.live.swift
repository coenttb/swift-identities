//
//  Identity.Backend.Client.MFA.BackupCodes.live.swift
//  coenttb-identities
//
//  Backup codes management implementation
//

import Dependencies
import Foundation
import IdentitiesTypes

extension Identity.MFA.BackupCodes.Client {
  package static func live(
    configuration: Identity.MFA.TOTP.Configuration
  ) -> Self {
    @Dependency(\.logger) var logger
    @Dependency(\.tokenClient) var tokenClient
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.request) var request

    return Identity.MFA.BackupCodes.Client(
      regenerate: {
        logger.debug("Backup codes regeneration initiated")

        // Get current identity (requires authentication)
        guard let request else { throw Identity.Backend.Error.requestUnavailable }
        guard let identity = request.auth.get(Identity.Record.self) else {
          logger.error("Not authenticated for backup code regeneration")
          throw Identity.Authentication.Error.notAuthenticated
        }

        // Check if TOTP is enabled with explicit database query
        let totpEnabled = try await database.read { db in
          let count = try await Identity.MFA.TOTP.Record
            .findConfirmedByIdentity(identity.id)
            .fetchCount(db)
          return count > 0
        }

        guard totpEnabled else {
          logger.error("TOTP not enabled for identity")
          throw Identity.MFA.TOTP.Client.ClientError.totpNotEnabled
        }

        // Generate new backup codes
        var codes: [String] = []
        for _ in 0..<configuration.backupCodeCount {
          let code = Identity.MFA.BackupCodes.Record.generateCode(
            length: configuration.backupCodeLength
          )
          codes.append(code)
        }

        try await database.write { [codes] db in
          // Delete existing codes
          try await Identity.MFA.BackupCodes.Record
            .delete()
            .where { $0.identityId.eq(identity.id) }
            .execute(db)

          // Create new codes
          for code in codes {
            let codeHash = try await Identity.MFA.BackupCodes.Record.hashCode(code)

            let backupCode = Identity.MFA.BackupCodes.Record.Draft(
              identityId: identity.id,
              codeHash: codeHash
            )

            try await Identity.MFA.BackupCodes.Record
              .insert { backupCode }
              .execute(db)
          }
        }

        logger.notice("Backup codes regenerated for identity: \(identity.id)")

        return codes
      },

      verify: { code, sessionToken in
        logger.debug("Backup code verification initiated")

        // Verify the MFA session token
        let mfaToken = try await tokenClient.verifyMFASession(sessionToken)

        // Check if token is valid
        guard mfaToken.isValid else {
          logger.error("MFA session token is expired or invalid")
          throw Identity.Authentication.Error.tokenExpired
        }

        let identityId = mfaToken.identityId

        // Get identity from database
        guard
          let identity = try await database.read({ db in
            try await Identity.Record
              .where { $0.id.eq(identityId) }
              .fetchOne(db)
          })
        else {
          logger.error("Identity not found: \(identityId)")
          throw Identity.Authentication.Error.accountNotFound
        }

        // Atomically verify and mark backup code as used
        // This prevents race conditions where the same code could be used concurrently
        @Dependency(\.date) var date

        let isValid = try await database.write { db in
          // Fetch all unused codes for this identity
          let unusedCodes = try await Identity.MFA.BackupCodes.Record
            .findUnusedByIdentity(identityId)
            .fetchAll(db)

          // Try to verify each code
          for backupCode in unusedCodes {
            if try await Identity.MFA.BackupCodes.Record.verifyCode(
              code.uppercased(),
              hash: backupCode.codeHash
            ) {
              // Atomically mark as used ONLY if still unused
              // This WHERE clause ensures the UPDATE only succeeds if isUsed is still false
              // If another concurrent request already used it, returning() will return nil
              let updated = try await Identity.MFA.BackupCodes.Record
                .where { $0.id.eq(backupCode.id) }
                .where { $0.isUsed.eq(false) }  // CRITICAL: prevents race condition
                .update { code in
                  code.isUsed = true
                  code.usedAt = date()
                }
                .returning(\.id)
                .fetchOne(db)

              // Only return true if we actually marked the code as used
              // If updated is nil, another request used it concurrently
              return updated != nil
            }
          }
          return false
        }

        guard isValid else {
          logger.warning("Invalid backup code for identity: \(identityId)")
          throw Identity.MFA.TOTP.Client.ClientError.invalidCode
        }

        logger.notice("Backup code verified successfully for identity: \(identityId)")

        // Generate full authentication tokens
        let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
          identity.id,
          identity.email,
          identity.sessionVersion
        )

        return Identity.Authentication.Response(
          accessToken: accessToken,
          refreshToken: refreshToken,
          mfaStatus: .satisfied
        )
      },

      remaining: {
        logger.debug("Fetching remaining backup codes count")

        // Get current identity (requires authentication)
        guard let request else { throw Identity.Backend.Error.requestUnavailable }
        guard let identity = request.auth.get(Identity.Record.self) else {
          logger.error("Not authenticated for backup code count")
          throw Identity.Authentication.Error.notAuthenticated
        }

        let count = try await database.read { db in
          try await Identity.MFA.BackupCodes.Record
            .findUnusedByIdentity(identity.id)
            .fetchCount(db)
        }

        logger.debug("Remaining backup codes for identity \(identity.id): \(count)")

        return count
      }
    )
  }
}
