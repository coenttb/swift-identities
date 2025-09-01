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
        
        @Dependency(\.identity.consumer) var configuration
        
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
            
        case .logout:
            return try await Identity.View.consumerResponse(view: .logout)
            
        case .reauthorize(let reauth):
            return try await Identity.API.response(api: .reauthorize(reauth))
        }
    }
    
    // MARK: - Feature Handlers
    
    private static func handleCreate(
        _ route: Identity.Creation.Route,
        configuration: Identity.Consumer.Configuration
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .create(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: .create(mapCreateView(view)))
        }
    }
    
    private static func handleAuthenticate(
        _ route: Identity.Authentication.Route,
        configuration: Identity.Consumer.Configuration
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .authenticate(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: .authenticate(mapAuthView(view)))
        }
    }
    
    private static func handleDelete(
        _ route: Identity.Deletion.Route,
        configuration: Identity.Consumer.Configuration
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .delete(api))
        case .view(_):
            return try await Identity.View.consumerResponse(view: .delete)
        }
    }
    
    private static func handleEmail(
        _ route: Identity.Email.Route,
        configuration: Identity.Consumer.Configuration
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .email(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: .email(mapEmailView(view)))
        }
    }
    
    private static func handlePassword(
        _ route: Identity.Password.Route,
        configuration: Identity.Consumer.Configuration
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .password(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: .password(mapPasswordView(view)))
        }
    }
    
    private static func handleMFA(
        _ route: Identity.MFA.Route,
        configuration: Identity.Consumer.Configuration
    ) async throws -> any AsyncResponseEncodable {
        switch route {
        case .api(let api):
            return try await Identity.API.response(api: .mfa(api))
        case .view(let view):
            return try await Identity.View.consumerResponse(view: .mfa(mapMFAView(view)))
        }
    }
    
    // MARK: - View Mapping Helpers
    
    private static func mapCreateView(_ view: Identity.Creation.View) -> Identity.View.Create {
        switch view {
        case .request:
            return .request
        case .verify:
            return .verify
        }
    }
    
    private static func mapAuthView(_ view: Identity.Authentication.View) -> Identity.View.Authenticate {
        switch view {
        case .credentials:
            return .credentials
        }
    }
    
    private static func mapEmailView(_ view: Identity.Email.View) -> Identity.View.Email {
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
    
    private static func mapPasswordView(_ view: Identity.Password.View) -> Identity.View.Password {
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
    
    private static func mapMFAView(_ view: Identity.MFA.View) -> Identity.View.MFA {
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
