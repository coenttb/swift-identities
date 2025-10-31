//
//  Identity.Logout.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 22/08/2025.
//

import Dependencies
import IdentitiesTypes
import ServerFoundationVapor
import Vapor

// MARK: - Response Handler

extension Identity.Logout {
  /// Handles the logout process.
  public static func response(
    client: Identity.Logout.Client,
    redirect: Identity.Frontend.Configuration.Redirect
  ) async throws -> any AsyncResponseEncodable {
    try? await client.current()

    @Dependency(\.request) var request
    guard let request else { throw Abort.requestUnavailable }

    let response = try await request.redirect(to: redirect.logoutSuccess().absoluteString)

    response.expire(cookies: .identity)

    return response
  }
}
