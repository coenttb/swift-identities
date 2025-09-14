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
        view: Identity.Creation.View
    ) async throws -> any AsyncResponseEncodable {
        
        
        switch view {
        case .request:
            return try await handleCreateRequest()
        case .verify(let verify):
            @Dependency(Identity.Frontend.Configuration.self) var configuration
            
            let router = configuration.identity.router
            let redirect = configuration.redirect
            
            return try await Identity.Frontend.htmlDocument(for: .create(.verify)) {
                try await Identity.Creation.Verification.View(
                    verificationAction: router.url(for: .create(.api(.verify(verify)))),
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
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        
        let router = configuration.identity.router
        
        return try await Identity.Frontend.htmlDocument(for: .create(.request)) {
            Identity.Creation.Request.View(
                loginHref: router.url(for: .login),
                accountCreateHref: router.url(for: .create(.view(.request))),
                createFormAction: router.url(for: .create(.api(.request(.init()))))
            )
        }
    }
}
