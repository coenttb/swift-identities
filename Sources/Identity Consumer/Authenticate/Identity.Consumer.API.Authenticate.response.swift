//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Consumer.API.Authenticate {
    package static func response(
        authenticate: Identity.Consumer.API.Authenticate
    ) async throws -> Response {

        @Dependency(\.identity.consumer.client) var client
        @Dependency(\.logger) var logger

        do {
            switch authenticate {
            case .token(let token):
                switch token {
                case .access(let access):
                    do {
                        return try await Response.success(true)
                            .withTokens(
                                for: client.login(
                                    accessToken: access.compactSerialization(),
                                    refreshToken: \.cookies.refreshToken?.string
                                )
                            )
                    } catch {
                        logger.error("Access token authentication failed", metadata: [
                            "component": "Consumer.Authenticate",
                            "operation": "accessToken",
                            "error": "\(error)"
                        ])
                        throw Abort(.internalServerError, reason: "Failed to authenticate account: \(error)")
                    }

                case .refresh(let refresh):
                    do {
                        let identityAuthenticationResponse = try await client.authenticate.token.refresh(refresh)

                        return Response.success(true)
                            .withTokens(for: identityAuthenticationResponse)
                    } catch {
                        logger.error("Refresh token authentication failed", metadata: [
                            "component": "Consumer.Authenticate",
                            "operation": "refreshToken",
                            "error": "\(error)"
                        ])
                        throw Abort(.internalServerError, reason: "Failed to authenticate account: \(error)")
                    }
                }

            case .credentials(let credentials):
                do {

                    let identityAuthenticationResponse = try await client.authenticate.credentials(credentials)

                    return Response.success(true)
                        .withTokens(for: identityAuthenticationResponse)
                } catch {
                    logger.error("Credentials authentication failed", metadata: [
                        "component": "Consumer.Authenticate",
                        "operation": "credentials",
                        "error": "\(error)"
                    ])
                    throw Abort(.internalServerError, reason: "Failed to authenticate account: \(error)")
                }

            case .apiKey(let apiKey):
                do {
                    let identityAuthenticationResponse = try await client.authenticate.apiKey(apiKey: apiKey.token)

                    return Response.success(true)
                        .withTokens(for: identityAuthenticationResponse)
                } catch {
                    logger.error("API key authentication failed", metadata: [
                        "component": "Consumer.Authenticate",
                        "operation": "apiKey",
                        "error": "\(error)"
                    ])
                    throw Abort(.internalServerError, reason: "Failed to authenticate account: \(error)")
                }
            }
        } catch {
            let response = Response.success(false, message: "Failed to authenticate with error: \(error)")
            response.expire(cookies: .identity)
            return response
        }
    }
}
