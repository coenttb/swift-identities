//
//  Identity.Authentication.Token.Client.live.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Dependencies
import EmailAddress
import IdentitiesTypes
import JWT
import Records
import ServerFoundationVapor

extension Identity.Authentication.Token.Client {
  package static func live() -> Self {
    @Dependency(\.logger) var logger

    return .init(
      access: { token in
        @Dependency(\.logger) var logger
        @Dependency(\.request) var request
        guard let request else { throw Identity.Backend.Error.requestUnavailable }
        @Dependency(\.tokenClient) var tokenClient
        @Dependency(\.date) var date
        @Dependency(\.defaultDatabase) var db

        do {
          let payload = try await tokenClient.verifyAccess(token)

          logger.trace(
            "Access token payload verified",
            metadata: [
              "component": "Backend.Authenticate",
              "identityId": "\(payload.identityId)",
            ]
          )

          // Single transaction for verification and update
          let identity = try await db.write { db in
            guard
              let identity = try await Identity.Record
                .where({ $0.id.eq(payload.identityId) })
                .fetchOne(db)
            else {
              throw Identity.Backend.Error.identityNotFound(identifier: .id(payload.identityId))
            }

            guard identity.email == payload.email else {
              throw Identity.Backend.Error.identityDetailsChanged
            }

            guard identity.sessionVersion == payload.sessionVersion else {
              throw Identity.Backend.Error.sessionInvalidated
            }

            // Update last login in same transaction
            try await Identity.Record
              .where { $0.id.eq(identity.id) }
              .update { record in
                record.lastLoginAt = date()
                record.updatedAt = date()
              }
              .execute(db)

            return identity
          }

          request.auth.login(identity)

          logger.debug(
            "Access token verified",
            metadata: [
              "component": "Backend.Authenticate",
              "operation": "verifyAccessToken",
              "identityId": "\(identity.id)",
            ]
          )

        } catch {
          logger.warning(
            "Access token verification failed",
            metadata: [
              "component": "Backend.Authenticate",
              "operation": "verifyAccessToken",
              "error": "\(error)",
            ]
          )
          throw Identity.Backend.Error.invalidToken(type: .access)
        }
      },
      refresh: { token in
        @Dependency(\.logger) var logger
        @Dependency(\.request) var request
        guard let request else { throw Identity.Backend.Error.requestUnavailable }
        @Dependency(\.tokenClient) var tokenClient
        @Dependency(\.defaultDatabase) var db

        do {
          let payload = try await tokenClient.verifyRefresh(token)

          // Single read transaction for identity verification
          let identity = try await db.read { db in
            guard
              let identity = try await Identity.Record
                .where({ $0.id.eq(payload.identityId) })
                .fetchOne(db)
            else {
              throw Identity.Backend.Error.identityNotFound(identifier: .id(payload.identityId))
            }

            guard identity.sessionVersion == payload.sessionVersion else {
              throw Identity.Backend.Error.tokenRevoked
            }

            return identity
          }

          logger.trace(
            "Refresh token verified",
            metadata: [
              "identity_id": .string(identity.id.uuidString)
            ]
          )

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

          return response

        } catch {
          logger.warning(
            "Refresh token verification failed",
            metadata: [
              "component": "Backend.Authenticate",
              "operation": "verifyRefreshToken",
              "error": "\(error)",
            ]
          )
          throw Identity.Backend.Error.invalidToken(type: .refresh)
        }
      }
    )
  }
}
