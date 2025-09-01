//
//  Identity.Logout.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 22/08/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import Dependencies
import Vapor

// MARK: - Response Handler

extension Identity.Logout {
    /// Handles the logout process.
    public static func response(
        client: Identity.Client,
        redirect: Identity.Frontend.Configuration.Redirect
    ) async throws -> any AsyncResponseEncodable {
        try? await client.logout()
        
        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }

        let response = try await request.redirect(to: redirect.logoutSuccess().absoluteString)

        response.expire(cookies: .identity)
        
        return response
    }
}
