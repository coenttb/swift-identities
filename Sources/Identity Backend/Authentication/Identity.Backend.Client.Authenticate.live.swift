//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 12/09/2024.
//

import Dependencies
import EmailAddress
import IdentitiesTypes
import JWT
import Records
import ServerFoundation
import ServerFoundationVapor

extension Identity.Authentication.Client {
  package static func live() -> Self {
    @Dependency(\.logger) var logger

    return .init(
      credentials: { username, password in
        let email: EmailAddress = try .init(username)

        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }
        @Dependency(\.date) var date

        do {
          // Use cached and optimized single query for authentication
          guard
            let authData = try await Identity.Record.verifyPasswordOptimized(
              email: email,
              password: password
            )
          else {
            logger.warning("Login attempt failed: Invalid credentials for email: \(email)")
            throw Abort(.unauthorized, reason: "Invalid credentials")
          }

          let identity = authData.identity

          guard identity.emailVerificationStatus == .verified else {
            logger.warning("Login attempt failed: Email not verified for: \(email)")
            throw Abort(.unauthorized, reason: "Email not verified")
          }

          // MFA status already included in authData
          if authData.totpEnabled {
            logger.info("MFA check for \(email): TOTP enabled")
          } else {
            logger.info("MFA check for \(email): No TOTP configured")
          }

          if authData.totpEnabled {
            // Generate MFA session token instead of full authentication
            @Dependency(\.tokenClient) var tokenClient
            let sessionToken = try await tokenClient.generateMFASession(
              identity.id,
              identity.sessionVersion,
              3,  // attempts remaining
              [.totp]  // available methods
            )

            logger.notice("MFA required for email: \(email) - throwing MFARequired error")

            // Return MFA challenge response
            throw Identity.Authentication.MFARequired(
              sessionToken: sessionToken,
              availableMethods: [.totp],
              attemptsRemaining: 3
            )
          }

          @Dependency(\.tokenClient) var tokenClient
          let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
            identity.id,
            identity.email,
            identity.sessionVersion
          )

          let response = Identity.Authentication.Response(
            accessToken: .init(accessToken),
            refreshToken: .init(refreshToken)
          )

          request.auth.login(identity)
          logger.notice("Login successful for email: \(email)")

          return response

        } catch let mfaRequired as Identity.Authentication.MFARequired {
          // Re-throw MFA required - this is not an error, it's part of the flow
          logger.info("Re-throwing MFA required for propagation")
          throw mfaRequired
        } catch {
          logger.warning("Login attempt failed: \(error)")
          throw Abort(.unauthorized, reason: "Invalid credentials")
        }
      },
      apiKey: { apiKeyString in
        @Dependency(\.request) var request
        @Dependency(\.logger) var logger
        @Dependency(\.date) var date
        @Dependency(\.tokenClient) var tokenClient
        @Dependency(\.defaultDatabase) var db
        guard let request else { throw Abort.requestUnavailable }

        do {
          // Single transaction for API key authentication with JOIN
          let authData = try await db.write { db in
            // Get API key with identity in single query
            let result = try await Identity.Authentication.ApiKey.Record
              .where { $0.key.eq(apiKeyString) }
              .where { $0.isActive.eq(true) }
              .where { apiKey in
                apiKey.validUntil > Date()
              }
              .join(Identity.Record.all) { apiKey, identity in
                apiKey.identityId.eq(identity.id)
              }
              .select { apiKey, identity in
                ApiKeyWithIdentity.Columns(
                  apiKey: apiKey,
                  identity: identity
                )
              }
              .fetchOne(db)

            // Update last used atomically in same transaction
            if let result = result {
              // Update API key last used
              try await Identity.Authentication.ApiKey.Record
                .where { $0.id.eq(result.apiKey.id) }
                .update { apiKey in
                  apiKey.lastUsedAt = date()
                }
                .execute(db)

              // Update identity last login
              try await Identity.Record
                .where { $0.id.eq(result.identity.id) }
                .update { identity in
                  identity.lastLoginAt = date()
                  identity.updatedAt = date()
                }
                .execute(db)
            }

            return result
          }

          guard let authData = authData else {
            logger.warning(
              "API key authentication failed",
              metadata: [
                "component": "Backend.Authenticate",
                "operation": "apiKeyAuth",
                "reason": "keyNotFound",
              ]
            )
            throw Abort(.unauthorized, reason: "Invalid API key")
          }

          let identity = authData.identity

          // Check if expired (though we already filtered in query)
          if authData.apiKey.isExpired {
            // Deactivate expired key
            try await db.write { db in
              try await Identity.Authentication.ApiKey.Record
                .where { $0.id.eq(authData.apiKey.id) }
                .update { apiKey in
                  apiKey.isActive = false
                }
                .execute(db)
            }
            throw Abort(.unauthorized, reason: "API key has expired")
          }

          let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
            identity.id,
            identity.email,
            identity.sessionVersion
          )

          let response = Identity.Authentication.Response(
            accessToken: .init(accessToken),
            refreshToken: .init(refreshToken)
          )

          request.auth.login(identity)

          logger.notice("API key authentication successful for identity: \(identity.id)")

          return response
        } catch {
          logger.error(
            "Unexpected error during api key verification: \(error.localizedDescription)"
          )
          throw Abort(.internalServerError, reason: "Unexpected error during api key verification")
        }
      }
    )
  }
}
