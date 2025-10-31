//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 06/02/2025.
//

import Identity_Shared
import ServerFoundationVapor
import IdentitiesTypes
import JWT
import Dependencies

extension Identity.Consumer {
    /// Token authenticator middleware for JWT-based authentication in Consumer deployments.
    ///
    /// This authenticator validates JWT access tokens from cookies,
    /// allowing protected routes to require authentication.
    public struct TokenAuthenticator: AsyncMiddleware {
        public init() {}

        public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Vapor.Response {
            return try await withDependencies {
                $0.request = request
            } operation: {
                @Dependency(\.tokenClient) var tokenClient

                // Try to authenticate using access token from cookies
                if let accessTokenString = request.cookies.accessToken?.string {
                    do {
                        let accessToken = try await tokenClient.verifyAccess(accessTokenString)
                        request.auth.login(accessToken)
                    } catch {
                        // Token invalid - request continues as unauthenticated
                        // Route handlers can require authentication if needed
                    }
                }

                return try await next.respond(to: request)
            }
        }
    }
}
