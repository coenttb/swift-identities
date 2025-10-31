//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2024.
//

import ServerFoundationVapor
import Foundation
import IdentitiesTypes

extension Identity.Provider.API {
    public static func response(
        api: Identity.Provider.API
    ) async throws -> Response {

        @Dependency(Identity.Provider.Configuration.self) var configuration
        let rateLimiters = configuration.provider.rateLimiters

        let rateLimitClient = try await Identity.API.rateLimit(
            api: api,
            rateLimiter: rateLimiters
        )

        // Then check protection
        do {
            try Identity.API.protect(api: api, with: Identity.Record.self)
        } catch {
            await rateLimitClient.recordFailure()
            throw error
        }

        switch api {
        case .authenticate(let authenticate):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Authentication.API.providerResponse(authenticate: authenticate)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case .create(let create):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Creation.API.providerResponse(create: create)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case .delete(let delete):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Deletion.API.providerResponse(delete: delete)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case .logout(let logout):
            await rateLimitClient.recordAttempt()
            @Dependency(\.identity) var identity
            switch logout {
            case .current:
                try await identity.logout.client.current()
            case .all:
                try await identity.logout.client.all()
            }
            await rateLimitClient.recordSuccess()
            return Response.success(true)

        case let .password(password):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Password.API.providerResponse(password: password)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case let .email(email):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Email.API.providerResponse(email: email)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case .reauthorize(let reauthorize):
            await rateLimitClient.recordAttempt()
            @Dependency(\.identity) var identity
            let data = try await identity.reauthorize.client.reauthorize(password: reauthorize.password)
            await rateLimitClient.recordSuccess()
            return Response.success(true, data: data)

        case .mfa:
            // MFA implementation will be added here
            // For now, return not implemented
            do {
                await rateLimitClient.recordAttempt()
                throw Abort(.notImplemented, reason: "MFA endpoints not yet implemented in Provider")
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case .oauth:
            // OAuth implementation will be added here
            // For now, return not implemented
            do {
                await rateLimitClient.recordAttempt()
                throw Abort(.notImplemented, reason: "OAuth endpoints not yet implemented in Provider")
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }
        }
    }
}
