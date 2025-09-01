//
//  Identity.Cookies.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import URLRouting
import IdentitiesTypes
import ServerFoundationVapor

extension Identity {
    /// Shared cookie definitions and utilities used across Provider, Consumer, and Standalone deployments.
    ///
    /// This namespace provides:
    /// - Standard cookie names used throughout the identity system
    /// - Path calculation utilities for security-restricted cookies
    /// - Common cookie-related constants
    public enum Cookies {
        
        /// Standard cookie names used across all identity deployments
        public enum Names {
            /// Cookie name for JWT access tokens (short-lived)
            public static let accessToken = "access_token"
            
            /// Cookie name for JWT refresh tokens (long-lived)
            public static let refreshToken = "refresh_token"
            
            /// Cookie name for reauthorization tokens (sensitive operations)
            public static let reauthorizationToken = "reauthorization_token"
            
            /// Cookie prefix for identity-specific metadata (Consumer-specific)
            public static let identityPrefix = "identity."
        }
        
        /// Path calculation utilities for security-restricted cookies
        public enum Paths {
            /// Calculate the path restriction for refresh token cookies.
            /// Refresh tokens should only be sent to the refresh endpoint for security.
            public static func refresh<Router: ParserPrinter>(
                using router: Router
            ) -> String where Router.Input == URLRequestData, Router.Output == Identity.Route {
                // Create a minimal JWT token just for path extraction
                // We use a dummy token with the refresh type claim
                let dummyJWT = JWT(
                    header: JWT.Header(alg: "HS256"),
                    payload: JWT.Payload(
                        sub: UUID().uuidString,
                        jti: UUID().uuidString,
                        additionalClaims: ["type": "refresh", "sev": 0]
                    ),
                    signature: Data()
                )
                
                return router.url(
                    for: .authenticate(.api(.token(.refresh(dummyJWT))))
                ).path
            }
            
            /// Calculate the path restriction for refresh token cookies (API-only router).
            public static func refresh<Router: ParserPrinter>(
                using router: Router
            ) -> String where Router.Input == URLRequestData, Router.Output == Identity.API {
                // Create a minimal JWT token just for path extraction
                // We use a dummy token with the refresh type claim
                let dummyJWT = JWT(
                    header: JWT.Header(alg: "HS256"),
                    payload: JWT.Payload(
                        sub: UUID().uuidString,
                        jti: UUID().uuidString,
                        additionalClaims: ["type": "refresh", "sev": 0]
                    ),
                    signature: Data()
                )
                
                return router.url(
                    for: .authenticate(.token(.refresh(dummyJWT)))
                ).path
            }
            
            /// Calculate the path restriction for reauthorization token cookies.
            /// Reauthorization tokens should only be sent to sensitive operation endpoints.
            public static func reauthorize<Router: ParserPrinter>(
                using router: Router
            ) -> String where Router.Input == URLRequestData, Router.Output == Identity.Route {
                return router.url(
                    for: .reauthorize(.init(password: ""))
                ).path
            }
            
            /// Calculate the path restriction for reauthorization token cookies (API-only router).
            public static func reauthorize<Router: ParserPrinter>(
                using router: Router
            ) -> String where Router.Input == URLRequestData, Router.Output == Identity.API {
                return router.url(
                    for: .reauthorize(.init(password: ""))
                ).path
            }
        }
        
        /// Cookie expiration times in seconds
        public enum Expiry {
            /// Access token expiry: 15 minutes
            public static let accessToken: Int = 60 * 15
            
            /// Refresh token expiry: 30 days
            public static let refreshToken: Int = 60 * 60 * 24 * 30
            
            /// Reauthorization token expiry: 5 minutes
            public static let reauthorizationToken: Int = 60 * 5
            
            /// Development mode access token: 1 hour
            public static let accessTokenDevelopment: Int = 60 * 60
            
            /// Development mode refresh token: 7 days
            public static let refreshTokenDevelopment: Int = 60 * 60 * 24 * 7
        }
    }
}

extension Identity.Cookies {
    /// Deployment mode for cookie configuration
    public enum DeploymentMode: Sendable {
        /// Same-origin deployment (Provider and Consumer on same domain)
        case sameOrigin
        
        /// Cross-subdomain deployment (e.g., api.example.com and app.example.com)
        case crossSubdomain(parentDomain: String)
        
        /// Cross-domain deployment (completely different domains)
        case crossDomain
        
        /// Development mode (localhost, different ports, etc.)
        case development
    }
}
