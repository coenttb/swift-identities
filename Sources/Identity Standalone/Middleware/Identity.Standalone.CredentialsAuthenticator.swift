//
//  Identity.Standalone.CredentialsAuthenticator.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Standalone {
    /// Credentials authenticator for username/password authentication in standalone deployments.
    ///
    /// This authenticator handles basic authentication with credentials,
    /// issuing JWT tokens upon successful authentication.
    public struct CredentialsAuthenticator: AsyncCredentialsAuthenticator {
        public typealias Credentials = Identity.Authentication.Credentials
        
        public init() {}
        
        public func authenticate(
            credentials: Credentials,
            for request: Request
        ) async throws {
            @Dependency(\.identity.client) var client
            @Dependency(\.tokenClient) var tokenClient
            
            do {
                // Authenticate with credentials
                let response = try await client.authenticate.credentials(
                    username: credentials.username,
                    password: credentials.password
                )
                
                // Verify and login with the access token
                let accessToken = try await tokenClient.verifyAccess(response.accessToken)
                request.auth.login(accessToken)
                
                // Store tokens in cookies for web clients
                request.cookies["access_token"] = HTTPCookies.Value(
                    string: response.accessToken,
                    isHTTPOnly: true,
                    sameSite: .strict
                )
                request.cookies["refresh_token"] = HTTPCookies.Value(
                    string: response.refreshToken,
                    isHTTPOnly: true,
                    sameSite: .strict
                )
                
            } catch {
                // Authentication failed - don't authenticate
                // This allows the request to continue as unauthenticated
            }
        }
    }
}

extension Identity.Standalone.CredentialsAuthenticator.Credentials: Vapor.Content {}
