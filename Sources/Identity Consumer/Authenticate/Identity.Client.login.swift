//
//  Identity.Consumer.Client.login.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 18/02/2025.
//

import Identity_Shared
import ServerFoundationVapor
import Dependencies
import IdentitiesTypes

extension Identity.Client {
    /// Authenticates a user using available tokens or refreshes them if needed.
    ///
    /// This method implements a token-based authentication flow:
    /// 1. First tries to validate the provided access token
    /// 2. If the access token is valid but near expiration, refreshes it
    /// 3. If the access token is invalid or unavailable, tries to use the refresh token
    /// 4. If no tokens are available, throws an error
    ///
    /// - Parameters:
    ///   - accessToken: An optional access token string from cookies or headers
    ///   - refreshToken: A function that extracts the refresh token from a request
    ///   - expirationBuffer: Time in seconds before token expiration when refresh should occur
    /// - Returns: An authentication response containing access and refresh tokens
    /// - Throws: Authentication errors if no valid tokens are available or if refresh fails
    public func login(
        accessToken: String?,
        refreshToken: (Vapor.Request) -> String?,
        expirationBuffer: TimeInterval = 300
    ) async throws -> Identity.Authentication.Response {

        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }

        @Dependency(\.date) var date

        // First, try to use the access token if available
        if let accessToken = accessToken {
            do {
                // Validate the access token
                try await authenticate.token.access(token: accessToken)

                // Check if token is near expiration and needs refresh
                guard let currentToken = request.auth.get(Identity.Token.Access.self)
                else { throw Identity.Client.Authenticate.Error.unauthorizedAccess }

                // Ensure we have a refresh token for potential refresh
                guard let refreshToken = refreshToken(request)
                else { throw Identity.Client.Authenticate.Error.noTokensAvailable }

                // If token is NOT near expiration, return existing tokens
                guard let expirationTime = currentToken.jwt.payload.exp,
                      date().addingTimeInterval(expirationBuffer) < expirationTime
                else {
                    // Token IS near expiration, refresh it
                    return try await authenticate.token.refresh(token: refreshToken)
                }

                // Token is still valid and not near expiration
                return .init(
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )

            } catch let error as Identity.Client.Authenticate.Error {
                // Propagate specific authentication errors
                throw error
            } catch {
                // Access token failed, try refresh token as fallback
                // Let it continue to the refresh token flow below
            }
        }

        // If we get here, either there was no access token or it failed validation
        // Try to use refresh token
        if let refreshTokenValue = refreshToken(request) {
            do {
                return try await authenticate.token.refresh(token: refreshTokenValue)
            } catch {
                // Just propagate the error, response handling is done in the response layer
                throw error
            }
        }

        // No tokens available
        throw Identity.Client.Authenticate.Error.noTokensAvailable
    }
}

extension Identity.Client.Authenticate {
    enum Error: Swift.Error {
        case noTokensAvailable
        case tokenNearExpiration
        case unauthorizedAccess
    }
}
