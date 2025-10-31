//
//  Identity+Get.swift
//  coenttb-identities
//
//  Created on migration from Fluent to StructuredQueriesPostgres
//

import Dependencies
import EmailAddress
import Foundation
import IdentitiesTypes
import Records
import ServerFoundationVapor
import Vapor

extension Identity.Record {
  public enum Get {
    public enum Identifier {
      case id(Identity.ID)
      case email(EmailAddress)
      case auth
    }
  }

  public static func get(
    by identifier: Identity.Record.Get.Identifier
  ) async throws -> Identity.Record {
    switch identifier {
    case .id(let id):
      @Dependency(\.defaultDatabase) var db
      guard
        let identity = try await db.read({ db in
          try await Identity.Record
            .where { $0.id.eq(id) }
            .fetchOne(db)
        })
      else {
        throw Abort(.notFound, reason: "Identity not found for id \(id)")
      }
      return identity

    case .email(let email):
      @Dependency(\.defaultDatabase) var db
      guard
        let identity = try await db.read({ db in
          try await Identity.Record
            .where { $0.email.eq(email) }
            .fetchOne(db)
        })
      else {
        throw Abort(.notFound, reason: "Identity not found for email \(email)")
      }
      return identity

    case .auth:
      @Dependency(\.request) var request
      @Dependency(\.logger) var logger
      guard let request else {
        logger.error(
          "Request not available for Identity.get(.auth)",
          metadata: [
            "component": "Identity.Record",
            "operation": "get.auth",
          ]
        )
        throw Abort.requestUnavailable
      }

      // First check for Identity.Token.Access (used by Standalone/Consumer)
      if let accessToken = request.auth.get(Identity.Token.Access.self) {
        return try await Identity.Record.get(by: .id(accessToken.identityId))
      }

      // Fall back to checking for Identity.Record (used by Provider)
      if let authIdentity = request.auth.get(Identity.Record.self) {
        // Refresh from database to ensure we have latest data
        return try await Identity.Record.get(by: .id(authIdentity.id))
      }

      // No authentication found
      throw Abort(.unauthorized, reason: "Not authenticated1")
    }
  }
}

// MARK: - Password Verification

extension Identity.Record {
  package init(
    id: Identity.ID,
    email: EmailAddress,
    password: String,
    emailVerificationStatus: Identity.Record.EmailVerificationStatus = .unverified
  ) throws {
    self.init(
      id: id,
      email: email,
      passwordHash: try Bcrypt.hash(password),
      emailVerificationStatus: emailVerificationStatus
    )
  }
}

// MARK: - Dependency (REMOVED)
// The identityQueries dependency has been deprecated.
// Use static methods on the models directly instead.
