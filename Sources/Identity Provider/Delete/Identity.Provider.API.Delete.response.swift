//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2024.
//

import Foundation
import IdentitiesTypes
import ServerFoundationVapor

extension Identity.Deletion.API {
  package static func providerResponse(
    delete: Identity.Deletion.API
  ) async throws -> Response {

    @Dependency(\.identity) var identity

    switch delete {
    case .request(let request):
      if request.reauthToken.isEmpty {
        throw Abort(.unauthorized, reason: "Invalid token")
      }

      do {
        try await identity.delete.request(request)
        return Response.success(true)
      } catch {
        throw Abort(.internalServerError, reason: "Failed to delete")
      }
    case .cancel:
      do {
        try await identity.delete.cancel()
        return Response.success(true)
      } catch {
        throw Abort(.internalServerError, reason: "Failed to delete")
      }
    case .confirm:
      do {
        try await identity.delete.confirm()
        return Response.success(true)
      } catch {
        throw Abort(.internalServerError, reason: "Failed to confirm deletion")
      }
    }
  }
}
