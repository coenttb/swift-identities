//
//  Identity.Frontend.View.protect.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Frontend {
    /// Protects views based on authentication requirements.
    ///
    /// This shared protection logic is used by both Consumer and Standalone
    /// to ensure consistent authentication checks across different deployment models.
    package static func protect(
        view: Identity.View,
        router: AnyParserPrinter<URLRequestData, Identity.Route>
    ) async throws {
        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }
        
        let isAuthenticated = request.auth.has(Identity.Token.Access.self)
        
        switch view {
        case .create, .authenticate:
            // These views should not be accessible when authenticated
            if isAuthenticated {
                throw Abort(.forbidden, reason: "Already authenticated")
            }
            
        case .delete, .email, .password(.change):
            // These views require authentication
            if !isAuthenticated {
                throw Abort(.unauthorized, reason: "Authentication required")
            }
            
            // Email change request requires reauthorization token
            if case .email(.change(.request)) = view {
                @Dependency(\.tokenClient) var tokenClient
                
                // Check for reauthorization token in cookies
                if let reauthorizationToken = request.cookies["reauthorization_token"]?.string {
                    do {
                        _ = try await tokenClient.verifyReauthorization(reauthorizationToken)
                    } catch {
                        // Invalid token, redirect to reauthorization
//                        throw Abort.redirect(to: "/identity/email/change/reauthorization")
                        throw Abort.redirect(to: router.path(for: .email(.view(.change(.reauthorization)))))
                    }
                } else {
                    // No token, redirect to reauthorization
                    throw Abort.redirect(to: router.path(for: .email(.view(.change(.reauthorization)))))
                }
            }
            
        case .logout:
            // Logout requires being logged in
            if !isAuthenticated {
                throw Abort(.forbidden, reason: "Not authenticated")
            }
            
        case .password(.reset):
            // Password reset doesn't require authentication
            break
            
        case .mfa:
            // MFA views have mixed authentication requirements
            // - Setup/manage require authentication
            // - Verify is part of the login flow (partial authentication)
            if case .mfa(.totp(.setup)) = view, !isAuthenticated {
                throw Abort(.unauthorized, reason: "Authentication required for TOTP setup")
            }
            if case .mfa(.totp(.manage)) = view, !isAuthenticated {
                throw Abort(.unauthorized, reason: "Authentication required for TOTP management")
            }
            if case .mfa(.manage) = view, !isAuthenticated {
                throw Abort(.unauthorized, reason: "Authentication required for MFA management")
            }
            if case .mfa(.backupCodes) = view, !isAuthenticated {
                throw Abort(.unauthorized, reason: "Authentication required for backup codes")
            }
            // .verify doesn't require full authentication (it's part of login flow)
        }
    }
}
