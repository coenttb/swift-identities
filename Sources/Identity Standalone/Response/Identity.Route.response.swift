//
//  Identity.Standalone.Route.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Route {
    /// Handles routing for standalone identity management using feature-based routing.
    ///
    /// This function processes both API and view routes for standalone deployments,
    /// providing complete identity management functionality within a single server.
    public static func standaloneResponse(
        route: Identity.Route
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .create(let createRoute):
            return try await handleStandaloneCreate(createRoute)
            
        case .authenticate(let authRoute):
            return try await handleStandaloneAuthenticate(authRoute)
            
        case .delete(let deleteRoute):
            return try await handleStandaloneDelete(deleteRoute)
            
        case .email(let emailRoute):
            return try await handleStandaloneEmail(emailRoute)
            
        case .password(let passwordRoute):
            return try await handleStandalonePassword(passwordRoute)
            
        case .mfa(let mfaRoute):
            return try await handleStandaloneMFA(mfaRoute)
            
        case .logout:
            return try await Identity.View.standaloneResponse(view: .logout)
            
        case .reauthorize(let reauth):
            return try await Identity.API.response(api: .reauthorize(reauth))
        }
    }
    
    // MARK: - Feature Handlers
    
    private static func handleStandaloneCreate(
        _ route: Identity.Creation.Route
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .create(api))
        case .view(let view):
            return try await Identity.View.standaloneResponse(view: .create(mapCreateView(view)))
        }
    }
    
    private static func handleStandaloneAuthenticate(
        _ route: Identity.Authentication.Route
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .authenticate(api))
        case .view(let view):
            return try await Identity.View.standaloneResponse(view: .authenticate(mapAuthView(view)))
        }
    }
    
    private static func handleStandaloneDelete(
        _ route: Identity.Deletion.Route
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .delete(api))
        case .view(let view):
            return try await Identity.View.standaloneResponse(view: .delete(view))
        }
    }
    
    private static func handleStandaloneEmail(
        _ route: Identity.Email.Route
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .email(api))
        case .view(let view):
            return try await Identity.View.standaloneResponse(view: .email(mapEmailView(view)))
        }
    }
    
    private static func handleStandalonePassword(
        _ route: Identity.Password.Route
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .password(api))
        case .view(let view):
            return try await Identity.View.standaloneResponse(view: .password(mapPasswordView(view)))
        }
    }
    
    private static func handleStandaloneMFA(
        _ route: Identity.MFA.Route
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .mfa(api))
        case .view(let view):
            return try await Identity.View.standaloneResponse(view: .mfa(mapMFAView(view)))
        }
    }
    
    // MARK: - View Mapping Helpers (shared with Consumer)
    
    private static func mapCreateView(_ view: Identity.Creation.View) -> Identity.Creation.View {
        switch view {
        case .request:
            return .request
        case .verify:
            return .verify
        }
    }
    
    private static func mapAuthView(_ view: Identity.Authentication.View) -> Identity.Authentication.View {
        switch view {
        case .credentials:
            return .credentials
        }
    }
    
    private static func mapEmailView(_ view: Identity.Email.View) -> Identity.Email.View {
        switch view {
        case .change(let change):
            switch change {
            case .request:
                return .change(.request)
            case .confirm:
                return .change(.confirm)
            case .reauthorization:
                return .change(.reauthorization)
            }
        }
    }
    
    private static func mapPasswordView(_ view: Identity.Password.View) -> Identity.Password.View {
        switch view {
        case .reset(let reset):
            switch reset {
            case .request:
                return .reset(.request)
            case .confirm:
                return .reset(.confirm)
            }
        case .change(let change):
            switch change {
            case .request:
                return .change(.request)
            }
        }
    }
    
    private static func mapMFAView(_ view: Identity.MFA.View) -> Identity.MFA.View {
        switch view {
        case .verify(let challenge):
            return .verify(challenge)
        case .manage:
            return .manage
        case .totp(let totp):
            switch totp {
            case .setup:
                return .totp(.setup)
            case .confirmSetup:
                return .totp(.confirmSetup)
            case .manage:
                return .totp(.manage)
            }
        case .backupCodes(let codes):
            switch codes {
            case .display:
                return .backupCodes(.display)
            case .verify(let challenge):
                return .backupCodes(.verify(challenge))
            }
        }
    }
}
