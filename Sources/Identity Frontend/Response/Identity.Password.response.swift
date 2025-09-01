//
//  Identity.Password.Handlers.swift
//  coenttb-identities
//
//  Feature-based handlers for Password functionality
//

import ServerFoundationVapor
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web
import Identity_Views
import Dependencies
import Language

// MARK: - Response Dispatcher

extension Identity.Password {
    /// Dispatches password view requests to appropriate handlers.
    public static func response(
        view: Identity.Password.View,
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        let router = configuration.router
        
        switch view {
        case .reset(let reset):
            switch reset {
            case .request:
                return try await Identity.Frontend.htmlDocument(
                    for: .password(.reset(.request)),
                    configuration: configuration
                ) {
                    Identity.Password.Reset.Request.View(
                        formActionURL: router.url(for: .password(.api(.reset(.request(.init()))))),
                        homeHref: configuration.navigation.home
                    )
                }
            case .confirm:
                return try await handleResetConfirm(configuration: configuration)
            }
            
        case .change(let change):
            switch change {
            case .request:
                return try await handleChangeRequest(configuration: configuration)
            }
        }
    }
}

extension Identity.Password {
  
    /// Handles password reset confirmation view.
    public static func handleResetConfirm(
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(\.request) var req
        
        let token = req?.parameters.get("token") ?? ""
        let router = configuration.router
        
        return try await Identity.Frontend.htmlDocument(
            for: .password(.reset(.confirm(.init()))),
            configuration: configuration
        ) {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    TranslatedString(
                        dutch: "Stel een nieuw wachtwoord in",
                        english: "Set a new password"
                    )
                    .font(.body(.regular))
                    
                    form(
                        action: .init(router.url(for: .password(.api(.reset(.confirm(.init()))))).relativePath),
                        method: .post
                    ) {
                        VStack {
                            input.hidden(
                                name: "token",
                                value: .init("\(token)")
                            )
                            
                            input.password(
                                name: "newPassword",
                                placeholder: "New Password",
                                required: true
                            )
                            
                            AnyHTML(
                                Button.submit() {
                                    TranslatedString(
                                        dutch: "Wachtwoord resetten",
                                        english: "Reset Password"
                                    )
                                }
                            )
                        }
                        .gap(.length(.medium))
                    }
                }
                .gap(.length(.medium))
            }
            .width(.percent(100))
        }
    }
    
    /// Handles password change request view.
    public static func handleChangeRequest(
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
        let router = configuration.router
        
        return try await Identity.Frontend.htmlDocument(
            for: .password(.change(.request)),
            configuration: configuration
        ) {
            try await Identity.Password.Change.Request.View(
                formActionURL: router.url(for: .password(.api(.change(.request(change: .init()))))),
                redirectOnSuccess: configuration.redirect.logoutSuccess()
            )
        }
    }
}
