//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 06/02/2025.
//

import Identity_Shared
import ServerFoundationVapor
import IdentitiesTypes
import JWT
import Dependencies

extension Identity.Consumer {
    public struct TokenAuthenticator: AsyncMiddleware {
        public init() {}

        @Dependency(\.identity.consumer.client) var client

        public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Vapor.Response {
            return try await withDependencies {
                $0.request = request
            } operation: {
                do {
                    let identityAuthenticationResponse = try await client.login(
                        accessToken: request.cookies.accessToken?.string,
                        refreshToken: { _ in request.cookies.refreshToken?.string }
                    )

                    let response = try await next.respond(to: request)

                    return response
                        .withTokens(for: identityAuthenticationResponse)
                } catch {
                    let response = try await next.respond(to: request)
                    response.expire(cookies: .identity)
                    return response
                }
            }
        }
    }
}
