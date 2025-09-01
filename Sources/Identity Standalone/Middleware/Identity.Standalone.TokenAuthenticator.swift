//
//  Identity.Standalone.TokenAuthenticator.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import JWT
import Dependencies
import Identity_Backend
import Identity_Frontend
import Records

extension Identity.Standalone {
    /// Token authenticator middleware for JWT-based authentication in standalone deployments.
    ///
    /// This authenticator validates JWT access tokens and manages token refresh,
    /// providing seamless authentication for standalone applications.
    public struct TokenAuthenticator: AsyncBearerAuthenticator {
        public typealias User = Identity.Token.Access
        
        public init() {}
        
        public func authenticate(
            bearer: BearerAuthorization,
            for request: Request
        ) async throws {
            @Dependency(\.identity.client) var client
            @Dependency(\.tokenClient) var tokenClient
            
            do {
                // Try to verify the access token
                let accessToken = try await tokenClient.verifyAccess(bearer.token)
                
                // Authenticate the request with the verified token
                request.auth.login(accessToken)
                
            } catch {
                // Token verification failed - don't authenticate
                // This allows the request to continue as unauthenticated
                // The route handler can decide if authentication is required
            }
        }
    }
}

// Cookie-based authentication support
extension Identity.Standalone {
    /// Cookie authenticator for session-based authentication in standalone deployments.
    public struct CookieAuthenticator: AsyncMiddleware {
        public init() {}
        
        public func respond(
            to request: Request,
            chainingTo next: AsyncResponder
        ) async throws -> Response {
            @Dependency(\.identity.client) var client
            @Dependency(\.tokenClient) var tokenClient
            @Dependency(\.logger) var logger
            
            // Check if this is a logout route - we need to authenticate but NOT refresh tokens
            let isLogoutRoute = request.url.path == "/api/logout" || 
                               request.url.path == "/api/logout/all" ||
                               request.url.path.hasSuffix("/logout") ||
                               request.url.path.hasSuffix("/logout/all")
            
            // Check for access token in cookies
            logger.trace("Cookie authentication check", metadata: [
                "component": "CookieAuth",
                "path": "\(request.url.path)",
                "hasCookies": "\(!request.cookies.all.isEmpty)",
                "isLogoutRoute": "\(isLogoutRoute)"
            ])
            
            if let accessTokenCookie = request.cookies["access_token"]?.string {
                do {
                    let accessToken = try await tokenClient.verifyAccess(accessTokenCookie)
                    
                    // In development, verify the identity still exists in the database
                    // This handles the case where the database is wiped between sessions
                    #if DEBUG
                    @Dependency(\.defaultDatabase) var database
                   
                    
                    let identityExists = try await database.read { db in
                        try await Database.Identity
                            .where { $0.id.eq(accessToken.identityId) }
                            .fetchOne(db)
                    } != nil
                    
                    if !identityExists {
                        logger.debug("Identity from token no longer exists in database", metadata: [
                            "component": "CookieAuth",
                            "identityId": "\(accessToken.identityId)",
                            "reason": "databaseWiped"
                        ])
                        // Clear cookies and continue as unauthenticated
                        let response = try await next.respond(to: request)
                        
                        response.expire(cookies: .identity)
                        
                        return response
                    }
                    #endif
                    
                    // Note: Session version validation is handled by the token verification itself
                    // The JWT contains the session version and if it doesn't match what's expected,
                    // the token refresh will fail appropriately.
                    // We don't need to query the database here in production.
                    
                    // Check if token should be refreshed proactively (but not for logout routes)
                    if accessToken.shouldRefresh && !isLogoutRoute {
                        logger.debug("Proactive token refresh initiated", metadata: [
                            "component": "CookieAuth",
                            "identityId": "\(accessToken.identityId)"
                        ])
                        
                        // Try to refresh if we have a refresh token
                        if let refreshTokenCookie = request.cookies["refresh_token"]?.string {
                            do {
                                let response = try await client.authenticate.token.refresh(refreshTokenCookie)
                                let newAccessToken = try await tokenClient.verifyAccess(response.accessToken)
                                
                                // Authenticate with new token
                                request.auth.login(newAccessToken)
                                logger.debug("Token proactively refreshed", metadata: [
                                    "component": "CookieAuth",
                                    "identityId": "\(newAccessToken.identityId)"
                                ])
                                
                                // Process request and add new tokens to response
                                let httpResponse = try await next.respond(to: request)

                                return httpResponse.withTokens(for: response)
                            } catch {
                                logger.debug("Proactive refresh failed, continuing with existing token", metadata: [
                                    "component": "CookieAuth",
                                    "error": "\(error)"
                                ])
                                // Continue with existing token
                            }
                        }
                    }
                    
                    request.auth.login(accessToken)
                    logger.trace("Access token verified", metadata: [
                        "component": "CookieAuth",
                        "identityId": "\(accessToken.identityId)"
                    ])
                } catch {
                    // For logout routes, don't try to refresh - just continue unauthenticated
                    if isLogoutRoute {
                        logger.debug("Access token invalid on logout route, continuing without refresh", metadata: [
                            "component": "CookieAuth",
                            "path": "\(request.url.path)"
                        ])
                        return try await next.respond(to: request)
                    }
                    
                    logger.debug("Access token invalid, attempting refresh", metadata: [
                        "component": "CookieAuth"
                    ])
                    // Check for refresh token
                    if let refreshTokenCookie = request.cookies["refresh_token"]?.string {
                        do {
                            // Try to refresh the token
                            let response = try await client.authenticate.token.refresh(refreshTokenCookie)
                            
                            // Authenticate the request with the new token BEFORE calling next
                            let accessToken = try await tokenClient.verifyAccess(response.accessToken)
                            request.auth.login(accessToken)
                            logger.debug("Tokens refreshed successfully", metadata: [
                                "component": "CookieAuth",
                                "identityId": "\(accessToken.identityId)"
                            ])
                            
                            // Now process the authenticated request
                            let httpResponse = try await next.respond(to: request)
                            
                            
                            
                            return httpResponse.withTokens(for: response)
                        } catch {
                            logger.debug("Authentication failed, continuing as unauthenticated", metadata: [
                                "component": "CookieAuth",
                                "reason": "tokenRefreshFailed"
                            ])
                            // Both tokens invalid - continue as unauthenticated
                        }
                    } else {
                        logger.trace("No refresh token available", metadata: [
                            "component": "CookieAuth"
                        ])
                    }
                }
            } else {
                logger.trace("No access token cookie found", metadata: [
                    "component": "CookieAuth"
                ])
            }
            
            return try await next.respond(to: request)
        }
    }
}
