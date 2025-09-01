//
//  Identity.Standalone.API.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import Identity_Frontend
import Identity_Shared
import Dependencies
import Vapor

extension Identity.Standalone.API {
    /// Handles API requests for standalone identity management.
    ///
    /// This function handles both standard identity API requests and
    /// Standalone-specific profile management requests.
    public static func response(
        api: Identity.Standalone.API,
    ) async throws -> any AsyncResponseEncodable {
        
        switch api {
        case .profile(let profileAPI):
            // Handle profile API requests (Standalone only)
            // Profile endpoints require authentication
            @Dependency(\.request) var request
            guard request?.identity?.isAuthenticated == true else {
                throw Abort(.unauthorized, reason: "Authentication required")
            }
            
            return try await Identity.API.Profile.response(profileAPI)
        }
    }
}


