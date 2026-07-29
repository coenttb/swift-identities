//
//  Identity.Logout.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 22/08/2025.
//

import Dependencies
import IdentitiesTypes
import Server_Vapor

import enum Server.Server

// MARK: - Response Handler

extension Identity.Logout {
    /// Handles the logout process.
    public static func response(
        client: Identity.Logout.Client,
        redirect: Identity.Frontend.Configuration.Redirect
    ) async throws -> Server.Response {
        try? await client.current()

        return try Server.Response.redirect(to: try await redirect.logoutSuccess().absoluteString)
            .expiringIdentityCookies()
    }
}
