//
//  Identity.Consumer.Route.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 21/02/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import Identity_Frontend
import Dependencies

extension Identity.Route {
    /// Handles route requests for Consumer deployments using feature-based routing.
    public static func consumerResponse(
        route: Identity.Route
    ) async throws -> any AsyncResponseEncodable {

        @Dependency(Identity.Consumer.Configuration.self) var config
        let configuration = config.consumer
        
        switch route {
        case .create(let createRoute):
            return try await handleCreate(createRoute, configuration: configuration)
            
        case .authenticate(let authRoute):
            return try await handleAuthenticate(authRoute, configuration: configuration)
            
        case .delete(let deleteRoute):
            return try await handleDelete(deleteRoute, configuration: configuration)
            
        case .email(let emailRoute):
            return try await handleEmail(emailRoute, configuration: configuration)
            
        case .password(let passwordRoute):
            return try await handlePassword(passwordRoute, configuration: configuration)
            
        case .mfa(let mfaRoute):
            return try await handleMFA(mfaRoute, configuration: configuration)

        case .logout(let logoutRoute):
            // Logout only has view, no API
            return try await Identity.View.consumerResponse(view: .logout)

        case .reauthorize(let reauth):
            switch reauth {
            case .api(let api):
                return try await Identity.API.response(api: .reauthorize(api))
            }

        case .oauth(let oauthRoute):
            // OAuth handling would go here
            throw Abort(.notImplemented, reason: "OAuth not yet implemented in Consumer")
        }
    }
    
    // MARK: - Feature Handlers
    
    private static func handleCreate(
        _ route: Identity.Creation.Route,
        configuration: Identity.Consumer.Configuration.Consumer
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .create(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: mapCreateView(view))
        }
    }

    private static func handleAuthenticate(
        _ route: Identity.Authentication.Route,
        configuration: Identity.Consumer.Configuration.Consumer
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .authenticate(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: mapAuthView(view))
        }
    }

    private static func handleDelete(
        _ route: Identity.Deletion.Route,
        configuration: Identity.Consumer.Configuration.Consumer
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .delete(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: .delete(view))
        }
    }

    private static func handleEmail(
        _ route: Identity.Email.Route,
        configuration: Identity.Consumer.Configuration.Consumer
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .email(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: mapEmailView(view))
        }
    }

    private static func handlePassword(
        _ route: Identity.Password.Route,
        configuration: Identity.Consumer.Configuration.Consumer
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .password(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: mapPasswordView(view))
        }
    }

    private static func handleMFA(
        _ route: Identity.MFA.Route,
        configuration: Identity.Consumer.Configuration.Consumer
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .mfa(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: mapMFAView(view))
        }
    }
    
    // MARK: - View Mapping Helpers

    private static func mapCreateView(_ view: Identity.Creation.View) -> Identity.View {
        switch view {
        case .request:
            return .create(.request)
        case .verify:
            return .create(.verify)
        }
    }

    private static func mapAuthView(_ view: Identity.Authentication.View) -> Identity.View {
        switch view {
        case .credentials:
            return .authenticate(.credentials)
        }
    }

    private static func mapEmailView(_ view: Identity.Email.View) -> Identity.View {
        switch view {
        case .change(let change):
            switch change {
            case .request:
                return .email(.change(.request))
            case .confirm:
                return .email(.change(.confirm))
            case .reauthorization:
                return .email(.change(.reauthorization))
            }
        }
    }

    private static func mapPasswordView(_ view: Identity.Password.View) -> Identity.View {
        switch view {
        case .reset(let reset):
            switch reset {
            case .request:
                return .password(.reset(.request))
            case .confirm:
                return .password(.reset(.confirm))
            }
        case .change(let change):
            switch change {
            case .request:
                return .password(.change(.request))
            }
        }
    }

    private static func mapMFAView(_ view: Identity.MFA.View) -> Identity.View {
        switch view {
        case .verify(let challenge):
            return .mfa(.verify(challenge))
        case .manage:
            return .mfa(.manage)
        case .totp(let totp):
            switch totp {
            case .setup:
                return .mfa(.totp(.setup))
            case .confirmSetup:
                return .mfa(.totp(.confirmSetup))
            case .manage:
                return .mfa(.totp(.manage))
            }
        case .backupCodes(let codes):
            switch codes {
            case .display:
                return .mfa(.backupCodes(.display))
            case .verify(let challenge):
                return .mfa(.backupCodes(.verify(challenge)))
            }
        }
    }
}
