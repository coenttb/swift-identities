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
        @Dependency(\.identity.require) var requireIdentity
        switch api {
        case .profile(let profileAPI):
            let identity = try await requireIdentity()
            
            return try await Identity.API.Profile.response(profileAPI)
        }
    }
}


