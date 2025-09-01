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

        @Dependency(\.identity.provider.rateLimiters) var rateLimiters

        let rateLimitClient = try await Identity.API.rateLimit(
            api: api,
            rateLimiter: rateLimiters
        )

        // Then check protection
        do {
            try Identity.API.protect(api: api, with: Database.Identity.self)
        } catch {
            await rateLimitClient.recordFailure()
            throw error
        }

        switch api {
        case .authenticate(let authenticate):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Provider.API.Authenticate.response(authenticate: authenticate)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case .create(let create):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Provider.API.Create.response(create: create)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case .delete(let delete):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Provider.API.Delete.response(delete: delete)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case .logout(let logout):
            await rateLimitClient.recordAttempt()
            @Dependency(\.identity.provider.client) var client
            switch logout {
            case .current:
                try await client.logout.current()
            case .all:
                try await client.logout.all()
            }
            await rateLimitClient.recordSuccess()
            return Response.success(true)

        case let .password(password):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Provider.API.Password.response(password: password)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case let .email(email):
            do {
                await rateLimitClient.recordAttempt()
                let response = try await Identity.Provider.API.Email.response(email: email)
                await rateLimitClient.recordSuccess()
                return response
            } catch {
                await rateLimitClient.recordFailure()
                throw error
            }

        case .reauthorize(let reauthorize):
            await rateLimitClient.recordAttempt()
            @Dependency(\.identity.provider.client) var client
            let data = try await client.reauthorize(password: reauthorize.password)
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
        }
    }
}
