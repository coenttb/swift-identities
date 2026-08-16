//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import Dependencies
import IdentitiesTypes
import Logger_Dependencies
import Logging
import Server_Vapor
import Vapor

import enum Server.Server

extension Identity.Authentication.API {
    package static func response(
        authenticate: Identity.Authentication.API
    ) async throws -> Server.Response {
        // swiftlint:disable:previous typed_throws_required

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
                        return try Server.Response.json(success: true)
                    } catch {
                        logger.error(
                            "Access token validation failed",
                            metadata: [
                                "component": "Consumer.Authenticate",
                                "operation": "accessToken",
                                "error": "\(error)",
                            ]
                        )
                        throw Abort(.unauthorized, reason: "Invalid access token")
                    }

                case .refresh(let refresh):
                    do {
                        let identityAuthenticationResponse = try await tokenClient.refresh(refresh)

                        return try Server.Response.json(success: true)
                            .withTokens(for: identityAuthenticationResponse)
                    } catch {
                        logger.error(
                            "Refresh token authentication failed",
                            metadata: [
                                "component": "Consumer.Authenticate",
                                "operation": "refreshToken",
                                "error": "\(error)",
                            ]
                        )
                        throw Abort(.unauthorized, reason: "Invalid refresh token")
                    }
                }

            case .credentials(let credentials):
                do {

                    let identityAuthenticationResponse = try await client.credentials(credentials)

                    return try Server.Response.json(success: true)
                        .withTokens(for: identityAuthenticationResponse)
                } catch {
                    logger.error(
                        "Credentials authentication failed",
                        metadata: [
                            "component": "Consumer.Authenticate",
                            "operation": "credentials",
                            "error": "\(error)",
                        ]
                    )
                    throw Abort(.unauthorized, reason: "Invalid credentials")
                }

            case .apiKey(let apiKey):
                do {
                    let identityAuthenticationResponse = try await client.apiKey(apiKey.token)

                    return try Server.Response.json(success: true)
                        .withTokens(for: identityAuthenticationResponse)
                } catch {
                    logger.error(
                        "API key authentication failed",
                        metadata: [
                            "component": "Consumer.Authenticate",
                            "operation": "apiKey",
                            "error": "\(error)",
                        ]
                    )
                    throw Abort(.unauthorized, reason: "Invalid API key")
                }
            }
        } catch {
            return try Server.Response.json(success: false, message: "Authentication failed")
                .expiringIdentityCookies()
        }
    }
}
