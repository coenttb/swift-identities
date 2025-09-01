//
//  Identity.Email.response.swift
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
import Vapor

// MARK: - Response Dispatcher

extension Identity.Email {
    /// Dispatches email view requests to appropriate handlers.
    public static func response(
        view: Identity.Email.View,
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        switch view {
        case .change(let change):
            switch change {
            case .request:
                return try await handleChangeRequest(configuration: configuration)
            case .confirm:
                return try await handleChangeConfirm(configuration: configuration)
            case .reauthorization:
                return try await handleChangeReauthorization(configuration: configuration)
            }
        }
    }
}

extension Identity.Email {
    // MARK: - Email Change Handlers
    
    /// Handles the email change request view.
    public static func handleChangeRequest(
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        let router = configuration.router
        let homeHref = configuration.navigation.home
        
        return try await Identity.Frontend.htmlDocument(for: .email(.change(.request)), configuration: configuration) {
            Identity.Email.Change.Request.View(
                formActionURL: router.url(for: .email(.api(.change(.request(.init()))))),
                homeHref: homeHref,
                reauthorizationURL: router.url(for: .email(.view(.change(.reauthorization))))
            )
        }
    }
    
    /// Handles the email change confirmation view.
    public static func handleChangeConfirm(
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        let redirect = configuration.redirect
        
        return try await Identity.Frontend.htmlDocument(for: .email(.change(.confirm)), configuration: configuration) {
            try await Identity.Email.Change.Confirmation.View(
                redirect: redirect.logoutSuccess()
            )
        }
    }
    
    /// Handles the email change reauthorization view.
    public static func handleChangeReauthorization(
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        let router = configuration.router
        
        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }
        
        // Get current user from authentication
        guard let token = request.auth.get(Identity.Token.Access.self) else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        
        return try await Identity.Frontend.htmlDocument(for: .email(.change(.reauthorization)), configuration: configuration) {
            Identity.Reauthorization.View(
                currentUserName: token.displayName,
                passwordResetHref: router.url(for: .password(.view(.reset(.request)))),
                confirmFormAction: router.url(for: .reauthorize(.init())),
                redirectOnSuccess: router.url(for: .email(.view(.change(.request))))
            )
        }
    }
}
