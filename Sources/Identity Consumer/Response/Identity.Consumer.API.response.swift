//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import Dependencies
import IdentitiesTypes
import Identity_Frontend
import Identity_Shared
import Server_Vapor
import Vapor

import enum Server.Server

extension Identity.API {
    public static func response(
        api: Identity.API
    ) async throws -> Server.Response {
        // swiftlint:disable:previous typed_throws_required

        @Dependency(\.identity) var identity
        @Dependency(\.identityConsumerConfiguration) var config
        let configuration = config.consumer

        do {
            try Identity.API.protect(
                api: api,
                with: Identity.Token.Access.self
            )
        } catch {
            throw Abort(.unauthorized)
        }

        let rateLimiter = configuration.rateLimiters

        let rateLimitClient = try await Identity.API.rateLimit(
            api: api,
            rateLimiter: rateLimiter
        )

        do {
            // Record the attempt BEFORE any actual operation
            await rateLimitClient.recordAttempt()

            // Special handling for logout which needs Cookie expiration
            if case .logout = api {
                try await identity.logout.client.current()

                let response = try Server.Response.json(success: true)
                    .expiringIdentityCookies()

                await rateLimitClient.recordSuccess()
                return response
            }

            // Special handling for reauthorize which sets cookies
            if case .reauthorize(let reauthorize) = api {
                let data = try await identity.reauthorize.client.reauthorize(
                    password: reauthorize.password
                )

                let response = try Server.Response.json(success: true)
                    .setting(
                        cookie: Identity.Cookies.Names.reauthorizationToken,
                        token: try data.compactSerialization(),
                        configuration: configuration.cookies.reauthorizationToken
                    )

                await rateLimitClient.recordSuccess()
                return response
            }

            // Delegate to Frontend for all other API handling
            // Convert Consumer redirect to Frontend redirect format
            let frontendRedirect = Identity.Frontend.Configuration.Redirect(
                loginSuccess: { _ in configuration.redirect.loginSuccess() },
                loginProtected: { configuration.redirect.loginProtected() },
                createProtected: { configuration.redirect.createProtected() },
                createVerificationSuccess: { configuration.redirect.createVerificationSuccess() },
                logoutSuccess: { configuration.redirect.logoutSuccess() }
            )

            let response = try await Identity.Frontend.response(
                api: api,
                identity: identity,
                cookies: configuration.cookies,
                redirect: frontendRedirect
            )

            await rateLimitClient.recordSuccess()

            return response
        } catch {
            await rateLimitClient.recordFailure()
            throw error
        }
    }
}
