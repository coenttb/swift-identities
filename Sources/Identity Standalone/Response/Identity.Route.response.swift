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
        case .create(let create):
            switch create {
            case .api(let api):
                return try await Identity.API.response(api: .create(api))
            case .view(let view):
                return try await Identity.View.standaloneResponse(view: .create(mapCreateView(view)))
            }
            
        case .authenticate(let authenticate):
            switch authenticate {
            case .api(let api):
                return try await Identity.API.response(api: .authenticate(api))
            case .view(let view):
                return try await Identity.View.standaloneResponse(view: .authenticate(mapAuthView(view)))
            }
            
        case .delete(let delete):
            switch delete {
            case .api(let api):
                return try await Identity.API.response(api: .delete(api))
            case .view(let view):
                return try await Identity.View.standaloneResponse(view: .delete(view))
            }
            
        case .email(let email):
            switch email {
            case .api(let api):
                return try await Identity.API.response(api: .email(api))
            case .view(let view):
                return try await Identity.View.standaloneResponse(view: .email(mapEmailView(view)))
            }
            
        case .password(let password):
            switch password {
            case .api(let api):
                return try await Identity.API.response(api: .password(api))
            case .view(let view):
                return try await Identity.View.standaloneResponse(view: .password(mapPasswordView(view)))
            }
            
        case .mfa(let mfa):
            switch mfa {
            case .api(let api):
                return try await Identity.API.response(api: .mfa(api))
            case .view(let view):
                return try await Identity.View.standaloneResponse(view: .mfa(mapMFAView(view)))
            }
            
        case .logout:
            return try await Identity.View.standaloneResponse(view: .logout)
            
        case .reauthorize(let reauth):
            switch reauth {
            case .api(let api):
                return try await Identity.API.response(api: .reauthorize(api))
            }
            
        case .oauth(let oauth):
            switch oauth {
            case .api(let oauth):
                return try await Identity.API.response(api: .oauth(oauth))
            case .view(let oauth):
                return try await Identity.View.standaloneResponse(view: .oauth(oauth))
            }
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
