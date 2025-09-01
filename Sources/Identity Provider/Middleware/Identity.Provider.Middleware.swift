//
//  Identity.Provider.Middleware.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 17/02/2025.
//

import Identity_Shared
import ServerFoundationVapor
import Dependencies
import JWT
@preconcurrency import Vapor

extension Identity.Provider {
    public struct Middleware: AsyncMiddleware {
        private let tokenAuthenticator: TokenAuthenticator
        private let apiKeyAuthenticator: ApiKeyAuthenticator
        private let credentialsAuthenticator: CredentialsAuthenticator

        public init(
            tokenAuthenticator: TokenAuthenticator = .init(),
            apiKeyAuthenticator: ApiKeyAuthenticator = .init(),
            credentialsAuthenticator: CredentialsAuthenticator = .init()
        ) {
            self.tokenAuthenticator = tokenAuthenticator
            self.apiKeyAuthenticator = apiKeyAuthenticator
            self.credentialsAuthenticator = credentialsAuthenticator
        }

        public func respond(
            to request: Request,
            chainingTo next: AsyncResponder
        ) async throws -> Response {
            return try await withDependencies {
                $0.request = request
            } operation: {
                do {
                    let tokenResponse = try await tokenAuthenticator.respond(to: request, chainingTo: next)
                    return tokenResponse
                } catch {

                }

                do {
                    if let bearerAuth = request.headers.bearerAuthorization {
                        try await apiKeyAuthenticator.authenticate(bearer: bearerAuth, for: request)
                        return try await next.respond(to: request)
                    }
                } catch {

                }

                do {
                    if let basicAuth = request.headers.basicAuthorization {
                        try await credentialsAuthenticator.authenticate(basic: basicAuth, for: request)
                        return try await next.respond(to: request)
                    }
                } catch {

                }

                return try await next.respond(to: request)
            }
        }
    }
}
