//
//  Identity.Email.response.swift
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

// MARK: - Response Dispatcher

extension Identity.Email {
    /// Dispatches email view requests to appropriate handlers.
    public static func response(
        view: Identity.Email.View,
    ) async throws -> any AsyncResponseEncodable {
        switch view {
        case .change(let change):
            switch change {
            case .request:
                return try await handleChangeRequest()
            case .confirm:
                return try await handleChangeConfirm()
            case .reauthorization:
                return try await handleChangeReauthorization()
            }
        }
    }
}

extension Identity.Email {
    // MARK: - Email Change Handlers
    
    /// Handles the email change request view.
    public static func handleChangeRequest(
        
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        @Dependency(\.identity.router) var router
        let homeHref = configuration.navigation.home
        
        return try await Identity.Frontend.htmlDocument(for: .email(.change(.request))) {
            Identity.Email.Change.Request.View(
                formActionURL: router.url(for: .email(.api(.change(.request(.init()))))),
                homeHref: homeHref,
                reauthorizationURL: router.url(for: .email(.view(.change(.reauthorization))))
            )
        }
    }
    
    /// Handles the email change confirmation view.
    public static func handleChangeConfirm(
        
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        let redirect = configuration.redirect
        
        return try await Identity.Frontend.htmlDocument(for: .email(.change(.confirm))) {
            try await Identity.Email.Change.Confirmation.View(
                redirect: redirect.logoutSuccess()
            )
        }
    }
    
    /// Handles the email change reauthorization view.
    public static func handleChangeReauthorization(
        
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        @Dependency(\.identity.router) var router
        
        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }
        
        // Get current user from authentication
        guard let token = request.auth.get(Identity.Token.Access.self) else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        
        return try await Identity.Frontend.htmlDocument(for: .email(.change(.reauthorization))) {
            Identity.Reauthorization.View(
                currentUserName: token.email.description,
                passwordResetHref: router.url(for: .view(.password(.reset(.request)))),
                confirmFormAction: router.url(for: .reauthorize(.api(.init()))),
                redirectOnSuccess: router.url(for: .view(.email(.change(.request))))
            )
        }
    }
}
