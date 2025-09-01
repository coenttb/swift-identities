//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import ServerFoundationVapor
import IdentitiesTypes
import Identity_Shared
import Identity_Frontend

extension Identity.Consumer.API {
    public static func response(
        api: Identity.Consumer.API
    ) async throws -> Response {

        @Dependency(\.identity.consumer.client) var client
        @Dependency(\.identity.consumer) var configuration

        do {
            try Identity.Consumer.API.protect(
                api: api,
                with: Identity.Token.Access.self
            )
        } catch {
            throw Abort(.unauthorized)
        }

        @Dependency(\.identity.consumer.rateLimiters) var rateLimiter

        let rateLimitClient = try await Identity.API.rateLimit(
            api: api,
            rateLimiter: rateLimiter
        )

        do {
            // Record the attempt BEFORE any actual operation
            await rateLimitClient.recordAttempt()
            
            // Special handling for logout which needs Cookie expiration
            if case .logout = api {
                try await client.logout()
                
                let response = Response.success(true)
                response.expire(cookies: .identity)
                
                await rateLimitClient.recordSuccess()
                return response
            }
            
            // Special handling for reauthorize which sets cookies
            if case .reauthorize(let reauthorize) = api {
                let data = try await client.reauthorize(password: reauthorize.password)
                
                let response = Response.success(true)
                response.cookies.reauthorizationToken = try .init(string: data.compactSerialization())
                
                await rateLimitClient.recordSuccess()
                return response
            }
            
            // Delegate to Frontend for all other API handling
            let response = try await Identity.Frontend.response(
                api: api,
                client: client,
                router: configuration.router,
                cookies: configuration.cookies
            )
            
            await rateLimitClient.recordSuccess()
            
            // Convert AsyncResponseEncodable to Response if needed
            if let response = response as? Response {
                return response
            } else {
                // This shouldn't happen since Frontend returns Response
                return Response.success(true)
            }
        } catch {
            await rateLimitClient.recordFailure()
            throw error
        }
    }
}
