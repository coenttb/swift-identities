//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 07/02/2025.
//

import ServerFoundationVapor

extension Identity.API {
    /// Protects an API endpoint based on its security requirements
    ///
    /// This function enforces the security policy declared by `securityRequirement`.
    /// Public endpoints pass through, authenticated endpoints require valid authentication.
    ///
    /// - Parameters:
    ///   - api: The API endpoint to protect
    ///   - type: The authenticatable type to require for protected endpoints
    /// - Throws: Authentication-related errors if endpoint requires authentication
    package static func protect<Authenticatable: Vapor.Authenticatable>(
        api: Identity.API,
        with type: Authenticatable.Type
    ) throws {
        // Only require authentication if the endpoint needs it
        guard api.requiresAuthentication else { return }
        try requireAuthentication(type)
    }
}
