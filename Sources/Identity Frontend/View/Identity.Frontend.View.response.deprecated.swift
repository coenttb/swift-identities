////
////  Identity.Frontend.View.response.swift
////  coenttb-identities
////
////  Created by Coen ten Thije Boonkkamp on 29/01/2025.
////
//
//import ServerFoundationVapor
//import Identities
//import CoenttbHTML
//import Coenttb_Web
//import Identity_Views
//import Dependencies
//import Language
//
//extension Identity.Frontend {
//    package static func response(
//        view: Identity.View,
//        configuration: Identity.Frontend.Configuration
//    ) async throws -> any AsyncResponseEncodable {
//        return try await Self.response(
//            view: view,
//            client: configuration.client,
//            router: configuration.router,
//            canonicalHref: configuration.canonicalHref,
//            hreflang: configuration.hreflang,
//            branding: configuration.branding,
//            navigation: configuration.navigation,
//            redirect: configuration.redirect
//        )
//    }
//    
//    /// Handles view rendering with configuration.
//    ///
//    /// This function provides the shared view response logic used by both
//    /// Consumer and Standalone.
//    package static func response(
//        view: Identity.View,
//        client: Identity.Client,
//        router: AnyParserPrinter<URLRequestData, Identity.Route>,
//        canonicalHref: @Sendable @escaping (Identity.View) -> URL?,
//        hreflang: @Sendable @escaping (Identity.View, Translating.Language) -> URL,
//        branding: Identity.Frontend.Configuration.Branding,
//        navigation: Identity.Frontend.Configuration.Navigation,
//        redirect: Identity.Frontend.Configuration.Redirect
//    ) async throws -> any AsyncResponseEncodable {
//        
//        // Check authentication requirements
//        try await protect(
//            view: view,
//            router: router
//        )
//        
//        // Render views
//        switch view {
//        case let .create(create):
//            return try await Identity.Creation.response(
//                view: create,
//                configuration: configuration
//            )
//            
//        case .delete:
//            return try await Identity.Deletion.response(
//                configuration: configuration
//            )
//            
//        case .authenticate(let authenticate):
//            return try await Identity.Authentication.response(
//                view: authenticate,
//                configuration: configuration
//            )
//            
//        case .logout:
//            return try await Identity.Logout.response(
//                client: client,
//                redirect: redirect
//            )
//            
//        case .email(let email):
//            return try await Identity.Email.response(
//                view: email,
//                configuration: configuration
//            )
//            
//        case .password(let password):
//            return try await Identity.Password.response(
//                view: password,
//                configuration: configuration
//            )
//            
//            
//        case .mfa(let mfa):
//            return try await Identity.MFA.response(
//                view: mfa,
//                configuration: configuration
//            )
//        }
//    }
//}
