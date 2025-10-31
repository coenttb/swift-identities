//
//  Identity.API+SecurityRequirements.swift
//  swift-identities
//
//  Declarative security requirements for API endpoints
//

import Foundation

/// Security requirements for an API endpoint
package enum SecurityRequirement: Equatable, Sendable {
    /// Public endpoint - no authentication required
    case `public`

    /// Requires valid authentication
    case authenticated

    /// Future: Requires specific permission
    // case authorized(Permission)
}

extension Identity.API {
    /// Declares the security requirements for this endpoint
    ///
    /// This property makes security policy explicit and auditable.
    /// The `protect()` function enforces these requirements.
    ///
    /// - Returns: The security requirement for this endpoint
    package var securityRequirement: SecurityRequirement {
        switch self {
        // Public endpoints - anyone can access
        case .authenticate, .create:
            return .public

        case .logout:
            return .public // Can logout even with expired tokens

        case .password(.reset):
            return .public // Password reset is public (uses email token)

        case .mfa(.verify):
            return .public // MFA verify uses session token, not auth

        case .oauth(.providers), .oauth(.authorize), .oauth(.callback):
            return .public // OAuth discovery and flow are public

        // Protected endpoints - require authentication
        case .delete, .email, .reauthorize:
            return .authenticated

        case .password(.change):
            return .authenticated

        case .mfa: // All MFA except .verify
            return .authenticated

        case .oauth(.connections), .oauth(.disconnect):
            return .authenticated
        }
    }

    /// Check if this endpoint requires authentication
    package var requiresAuthentication: Bool {
        securityRequirement == .authenticated
    }
}
