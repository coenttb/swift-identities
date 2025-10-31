//
//  Identity.API.Profile.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Dependencies
import Foundation
import IdentitiesTypes
import Identity_Backend
import Records
import ServerFoundationVapor
import Vapor

extension Identity.API.Profile {
  /// Handles profile API requests for standalone deployments.
  public static func response(
    _ profile: Identity.API.Profile
  ) async throws -> any AsyncResponseEncodable {

    // Get authenticated identity
    let identity = try await Identity.Record.get(by: .auth)

    switch profile {
    case .get:
      @Dependency(\.defaultDatabase) var db
      @Dependency(\.uuid) var uuid
      @Dependency(\.date) var date

      let profile = try await db.write { db in
        let defaultProfile = Identity.Profile.Record.Draft(
          identityId: identity.id,
          displayName: nil,
          createdAt: date(),
          updatedAt: date()
        )

        try await Identity.Profile.Record
          .upsertByIdentityId(defaultProfile)
          .execute(db)

        // Fetch the profile (guaranteed to exist now)
        return try await Identity.Profile.Record
          .findByIdentity(identity.id)
          .fetchOne(db)!
      }

      // Return profile data as JSON
      // Use the response structure for consistency with updateDisplayName
      struct ProfileResponse: Codable {
        let id: UUID
        let identityId: UUID
        let displayName: String?
        let email: String
        let createdAt: Date
        let updatedAt: Date
      }

      let response = ProfileResponse(
        id: profile.id.rawValue,
        identityId: profile.identityId.rawValue,
        displayName: profile.displayName,
        email: identity.email.description,
        createdAt: profile.createdAt,
        updatedAt: profile.updatedAt
      )

      return Vapor.Response.success(true, data: response)

    case .updateDisplayName(let request):
      @Dependency(\.request) var vaporRequest
      @Dependency(\.tokenClient) var tokenClient
      @Dependency(\.defaultDatabase) var db
      @Dependency(\.uuid) var uuid
      @Dependency(\.date) var date

      // Validate display name if provided
      if let displayName = request.displayName {
        try Identity.Profile.Record.validateDisplayName(displayName)
      }

      // Use UPSERT to create or update profile atomically
      try await db.write { db in
        let profile = Identity.Profile.Record.Draft(
          identityId: identity.id,
          displayName: request.displayName,
          createdAt: date(),
          updatedAt: date()
        )

        try await Identity.Profile.Record
          .upsertByIdentityId(profile)
          .execute(db)
      }

      // Generate new tokens with updated displayName
      let (newAccessToken, newRefreshToken) = try await tokenClient.generateTokenPair(
        identity.id,
        identity.email,
        identity.sessionVersion
      )

      // Check if this is a form submission (browser request)
      let isFormSubmission =
        vaporRequest?.headers["accept"].contains {
          $0.contains("text/html")
        } ?? false

      if isFormSubmission {
        // Browser request - update cookies with new tokens and redirect
        let response = Vapor.Response(
          status: .seeOther,
          headers: ["Location": "/profile/edit?success=displayName"]
        )

        response.expire(cookies: .identity)

        return
          response
          .withTokens(for: .init(accessToken: newAccessToken, refreshToken: newRefreshToken))
      } else {
        // API request - return JSON with new tokens
        return Vapor.Response.success(
          true,
          data: [
            "displayName": request.displayName,
            "accessToken": newAccessToken,
            "refreshToken": newRefreshToken,
          ]
        )
      }
    }
  }
}
