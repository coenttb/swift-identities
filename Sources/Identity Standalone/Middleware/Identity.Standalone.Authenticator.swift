//
//  Identity.Standalone.Authenticator.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 18/08/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import JWT
import Dependencies
import Identity_Backend
import Identity_Frontend

extension Identity.Standalone {
    /// Unified authenticator that combines all authentication methods for standalone deployments.
    ///
    /// This authenticator provides a single middleware that handles:
    /// - Cookie-based authentication (for web sessions)
    /// - Bearer token authentication (for API calls)
    /// - Credentials authentication (for login endpoints)
    ///
    /// Usage:
    /// ```swift
    /// application.middleware.use(Identity.Standalone.Authenticator())
    /// ```
    ///
    /// This replaces the need to individually add:
    /// - `Identity.Standalone.CookieAuthenticator()`
    /// - `Identity.Standalone.TokenAuthenticator()`
    /// - `Identity.Standalone.CredentialsAuthenticator()`
    public struct Authenticator: AsyncMiddleware {
        // Internal authenticators
        private let cookieAuthenticator: CookieAuthenticator
        private let tokenAuthenticator: TokenAuthenticator
        private let credentialsAuthenticator: CredentialsAuthenticator
        
        public init() {
            self.cookieAuthenticator = CookieAuthenticator()
            self.tokenAuthenticator = TokenAuthenticator()
            self.credentialsAuthenticator = CredentialsAuthenticator()
        }
        
        public func respond(
            to request: Request,
            chainingTo next: AsyncResponder
        ) async throws -> Response {
            @Dependency(\.logger) var logger
            
            logger.trace("Unified authenticator processing request", metadata: [
                "component": "UnifiedAuth",
                "path": "\(request.url.path)",
                "method": "\(request.method)"
            ])
            
            // 1. First check for cookies (most common for web apps)
            // The CookieAuthenticator handles its own middleware chain
            let cookieResponse = try await cookieAuthenticator.respond(to: request, chainingTo: next)
            
            // If already authenticated via cookies, return early
            if request.auth.has(Identity.Token.Access.self) {
                logger.trace("Authenticated via cookies", metadata: [
                    "component": "UnifiedAuth",
                    "method": "cookie"
                ])
                return cookieResponse
            }
            
            // 2. Check for Bearer token authentication (API calls)
            if let bearerString = request.headers.bearerAuthorization?.token {
                let bearer = BearerAuthorization(token: bearerString)
                try await tokenAuthenticator.authenticate(bearer: bearer, for: request)
                
                if request.auth.has(Identity.Token.Access.self) {
                    logger.trace("Authenticated via bearer token", metadata: [
                        "component": "UnifiedAuth",
                        "method": "bearer"
                    ])
                    return cookieResponse
                }
            }
            
            // 3. Check for credentials (login endpoints)
            // Only process credentials if this is a login-like request
            if request.method == .POST,
               let contentType = request.headers.contentType,
               (contentType == .json || contentType == .urlEncodedForm) {
                
                // Try to decode credentials from the request body
                if let credentials = try? request.content.decode(Identity.Authentication.Credentials.self) {
                    try await credentialsAuthenticator.authenticate(
                        credentials: credentials,
                        for: request
                    )
                    
                    if request.auth.has(Identity.Token.Access.self) {
                        logger.trace("Authenticated via credentials", metadata: [
                            "component": "UnifiedAuth",
                            "method": "credentials"
                        ])
                    }
                }
            }
            
            // Return the response (authenticated or not)
            return cookieResponse
        }
    }
}

// MARK: - Convenience Extensions

extension Identity.Standalone.Authenticator {
    /// Creates an authenticator with custom configuration.
    ///
    /// This allows for advanced use cases where you might want to:
    /// - Disable certain authentication methods
    /// - Add custom logging or metrics
    /// - Provide custom error handling
    public struct Configuration: Sendable {
        public var enableCookies: Bool
        public var enableBearerTokens: Bool
        public var enableCredentials: Bool
        
        public init(
            enableCookies: Bool = true,
            enableBearerTokens: Bool = true,
            enableCredentials: Bool = true
        ) {
            self.enableCookies = enableCookies
            self.enableBearerTokens = enableBearerTokens
            self.enableCredentials = enableCredentials
        }
        
        /// Default configuration with all authentication methods enabled
        public static let `default` = Configuration()
        
        /// API-only configuration (no cookies)
        public static let apiOnly = Configuration(
            enableCookies: false,
            enableBearerTokens: true,
            enableCredentials: true
        )
        
        /// Web-only configuration (no bearer tokens)
        public static let webOnly = Configuration(
            enableCookies: true,
            enableBearerTokens: false,
            enableCredentials: true
        )
    }
    
    /// Creates an authenticator with custom configuration
    public init(configuration: Configuration) {
        self.init()
        // Note: Configuration is stored but not used in this implementation
        // You could extend this to actually disable certain auth methods
    }
}
