//
//  Identity.Deletion.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 22/08/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import HTML
import ServerFoundationVapor
import Identity_Views
import Dependencies
import Language

// MARK: - Response Dispatcher

extension Identity.Deletion {
    /// Dispatches delete view requests to appropriate handlers.
    public static func response(
    ) async throws -> any AsyncResponseEncodable {
        // Delete only has one view (request), no subviews
        return try await handleRequest()
    }
}

extension Identity.Deletion {
    // MARK: - Delete Handlers
    
    /// Handles the account deletion request view.
    public static func handleRequest(
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        
        let router = configuration.identity.router
        let homeHref = configuration.navigation.home
        
        return try await Identity.Frontend.htmlDocument(for: .delete(.request)) {
            Identity.Deletion.Request.View(
                deleteRequestAction: router.url(for: .delete(.api(.request(.init())))),
                cancelAction: router.url(for: .delete(.api(.cancel))),
                homeHref: homeHref,
                reauthorizationURL: router.url(for: .reauthorize(.api(.init())))
            )
        }
    }
}
