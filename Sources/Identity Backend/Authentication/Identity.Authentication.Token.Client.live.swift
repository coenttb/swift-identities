//
//  Identity.Authentication.Token.Client.live.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import Dependencies
import IdentitiesTypes
import JWT
import EmailAddress

extension Identity.Authentication.Token.Client {
    package static func live() -> Self {
        @Dependency(\.logger) var logger
        
        return .init(
            access: { token in
                @Dependency(\.logger) var logger
                @Dependency(\.request) var request
                guard let request else { throw Abort.requestUnavailable }
                @Dependency(\.tokenClient) var tokenClient
                @Dependency(\.date) var date

                do {
                    let payload = try await tokenClient.verifyAccess(token)

                    logger.trace("Access token payload verified", metadata: [
                        "component": "Backend.Authenticate",
                        "identityId": "\(payload.identityId)"
                    ])

                    guard let identity = try await Database.Identity.findById(payload.identityId) else {
                        throw Abort(.unauthorized, reason: "Identity not found")
                    }

                    guard identity.email == payload.email else {
                        throw Abort(.unauthorized, reason: "Identity details have changed")
                    }
                    
                    guard identity.sessionVersion == payload.sessionVersion else {
                        throw Abort(.unauthorized, reason: "Session has been invalidated")
                    }

                    // Use optimized update without fetching
                    try await Database.Identity.updateLastLogin(id: identity.id)

                    request.auth.login(identity)

                    logger.debug("Access token verified", metadata: [
                        "component": "Backend.Authenticate",
                        "operation": "verifyAccessToken",
                        "identityId": "\(identity.id)"
                    ])

                } catch {
                    logger.warning("Access token verification failed", metadata: [
                        "component": "Backend.Authenticate",
                        "operation": "verifyAccessToken",
                        "error": "\(error)"
                    ])
                    throw Abort(.unauthorized, reason: "Invalid access token")
                }
            },
            refresh: { token in
                @Dependency(\.logger) var logger
                @Dependency(\.request) var request
                guard let request else { throw Abort.requestUnavailable }
                @Dependency(\.tokenClient) var tokenClient

                do {
                    let payload = try await tokenClient.verifyRefresh(token)

                    guard let identity = try await Database.Identity.findById(payload.identityId) else {
                        throw Abort(.unauthorized, reason: "Identity not found")
                    }

                    guard identity.sessionVersion == payload.sessionVersion else {
                        throw Abort(.unauthorized, reason: "Token has been revoked")
                    }

                    logger.debug("Refresh token verified", metadata: [
                        "component": "Backend.Authenticate",
                        "operation": "verifyRefreshToken",
                        "identityId": "\(identity.id)"
                    ])

                    let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
                        identity.id,
                        identity.email,
                        identity.sessionVersion
                    )
                    
                    let response = Identity.Authentication.Response(
                        accessToken: .init(accessToken),
                        refreshToken: .init(refreshToken)
                    )

                    request.auth.login(identity)

                    return response

                } catch {
                    logger.warning("Refresh token verification failed", metadata: [
                        "component": "Backend.Authenticate",
                        "operation": "verifyRefreshToken",
                        "error": "\(error)"
                    ])
                    throw Abort(.unauthorized, reason: "Invalid refresh token")
                }
            }
        )
    }
}