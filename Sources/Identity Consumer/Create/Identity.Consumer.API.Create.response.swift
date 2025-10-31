//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import IdentitiesTypes
import ServerFoundationVapor

extension Identity.Creation.API {
  public static func response(
    create: Identity.Creation.API
  ) async throws -> Response {

    @Dependency(\.identity) var identity
    let client = identity.create.client

    switch create {
    case .request(let request):
      do {
        try await client.request(request)
        return Response.success(true)
      } catch {
        throw Abort(.internalServerError, reason: "Failed to request account creation")
      }

    case .verify(let verify):
      do {
        try await client.verify(email: verify.email, token: verify.token)
        return Response.success(true)
      } catch {
        throw Abort(.internalServerError, reason: "Failed to verify account creation")
      }
    }
  }
}
