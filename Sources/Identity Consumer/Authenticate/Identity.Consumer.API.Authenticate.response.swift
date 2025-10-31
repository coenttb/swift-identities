//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Authentication.API {
    package static func response(
        authenticate: Identity.Authentication.API
    ) async throws -> Response {

        @Dependency(\.identity) var identity
        @Dependency(\.logger) var logger

        let client = identity.authenticate.client
        let tokenClient = identity.authenticate.token

        do {
            switch authenticate {
            case .token(let token):
                switch token {
                case .access(let access):
                    do {
                        try await tokenClient.access(access)
                        return Response.success(true)
                    } catch {
                        logger.error("Access token validation failed", metadata: [
                            "component": "Consumer.Authenticate",
                            "operation": "accessToken",
                            "error": "\(error)"
                        ])
                        throw Abort(.unauthorized, reason: "Invalid access token")
                    }

                case .refresh(let refresh):
                    do {
                        let identityAuthenticationResponse = try await tokenClient.refresh(refresh)

                        return Response.success(true)
                            .withTokens(for: identityAuthenticationResponse)
                    } catch {
                        logger.error("Refresh token authentication failed", metadata: [
                            "component": "Consumer.Authenticate",
                            "operation": "refreshToken",
                            "error": "\(error)"
                        ])
                        throw Abort(.unauthorized, reason: "Invalid refresh token")
                    }
                }

            case .credentials(let credentials):
                do {

                    let identityAuthenticationResponse = try await client.credentials(credentials)

                    return Response.success(true)
                        .withTokens(for: identityAuthenticationResponse)
                } catch {
                    logger.error("Credentials authentication failed", metadata: [
                        "component": "Consumer.Authenticate",
                        "operation": "credentials",
                        "error": "\(error)"
                    ])
                    throw Abort(.unauthorized, reason: "Invalid credentials")
                }

            case .apiKey(let apiKey):
                do {
                    let identityAuthenticationResponse = try await client.apiKey(apiKey.token)

                    return Response.success(true)
                        .withTokens(for: identityAuthenticationResponse)
                } catch {
                    logger.error("API key authentication failed", metadata: [
                        "component": "Consumer.Authenticate",
                        "operation": "apiKey",
                        "error": "\(error)"
                    ])
                    throw Abort(.unauthorized, reason: "Invalid API key")
                }
            }
        } catch {
            let response = Response.success(false, message: "Authentication failed")
            response.expire(cookies: .identity)
            return response
        }
    }
}
