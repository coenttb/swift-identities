//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/02/2025.
//

import IdentitiesTypes
import ServerFoundationVapor

extension Identity.Email.API {
  public static func response(
    email: Identity.Email.API
  ) async throws -> Response {
    @Dependency(\.identity) var identity
    let client = identity.email.change.client

    switch email {
    case .change(let change):
      switch change {
      case .request(let request):
        do {
          let data = try await client.request(request)
          switch data {
          case .success:
            return Response.success(true)

          case .requiresReauthentication:
            return Response.success(false, message: "Requires reauthorization")
          }
        } catch {
          throw Abort(.internalServerError, reason: "Failed to request email change")
        }

      case .confirm(let confirm):
        do {
          let identityEmailChangeConfirmResponse = try await client.confirm(confirm)

          return Response.success(true)
            .withTokens(for: identityEmailChangeConfirmResponse)
        } catch {
          throw Abort(.internalServerError, reason: "Failed to confirm email change")
        }
      }
    }
  }
}
