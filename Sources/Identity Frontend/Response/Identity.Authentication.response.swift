//
//  Identity.Authentication.response.swift
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

extension Identity.Authentication {
    /// Dispatches authentication view requests to appropriate handlers.
    public static func response(
        view: Identity.Authentication.View
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        
        switch view {
        case .credentials:
            return try await Identity.Frontend.htmlDocument(for: .authenticate(.credentials)) {
                Identity.Authentication.Credentials.View(
                    passwordResetHref: configuration.identity.router.url(for: .password(.view(.reset(.request)))),
                    accountCreateHref: configuration.identity.router.url(for: .create(.view(.request))),
                    loginFormAction: configuration.identity.router.url(for: .authenticate(.api(.credentials(.init()))))
                )
            }
        }
    }
}
