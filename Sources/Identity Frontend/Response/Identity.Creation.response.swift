//
//  File.swift
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
import Vapor

extension Identity.Creation {
    /// Dispatches password view requests to appropriate handlers.
    public static func response(
        view: Identity.Creation.View,
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        switch view {
        case .request:
            return try await handleCreateRequest(configuration: configuration)
        case .verify(let verify):
            let router = configuration.router
            let redirect = configuration.redirect
            
            return try await Identity.Frontend.htmlDocument(for: .creation(.verify), configuration: configuration) {
                try await Identity.Creation.Verification.View(
                    verificationAction: router.url(for: .creation(.api(.verify(verify)))),
                    redirectURL: redirect.createVerificationSuccess()
                )
            }
        }
    }
}

extension Identity.Creation {
    // MARK: - Create Handlers
    
    /// Handles the account creation request view.
    public static func handleCreateRequest(
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        let router = configuration.router
        
        return try await Identity.Frontend.htmlDocument(for: .creation(.request), configuration: configuration) {
            Identity.Creation.Request.View(
                loginHref: router.url(for: .login),
                accountCreateHref: router.url(for: .creation(.view(.request))),
                createFormAction: router.url(for: .creation(.api(.request(.init()))))
            )
        }
    }
}
