//
//  Identity.Authentication.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 22/08/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web
import Identity_Views
import Dependencies
import Language

// MARK: - Response Dispatcher

extension Identity.Authentication {
    /// Dispatches authentication view requests to appropriate handlers.
    public static func response(
        view: Identity.Authentication.View,
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        switch view {
        case .credentials:
            return try await Identity.Frontend.htmlDocument(for: .authenticate(.credentials), configuration: configuration) {
                Identity.Authentication.Credentials.View(
                    passwordResetHref: configuration.router.url(for: .password(.view(.reset(.request)))),
                    accountCreateHref: configuration.router.url(for: .create(.view(.request))),
                    loginFormAction: configuration.router.url(for: .authenticate(.api(.credentials(.init()))))
                )
            }
        }
    }
}
