//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 11/02/2025.
//

import Identity_Shared
import ServerFoundationVapor
import Dependencies
import EmailAddress
import IdentitiesTypes
import JWT
import Throttling

extension Identity.Consumer.Client.Authenticate {
    package static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Consumer.API.Authenticate) throws -> URLRequest
    ) -> Self {
        @Dependency(\.identity.consumer.client) var client
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest
        @Dependency(\.tokenClient) var tokenClient
        
        return .init(
            credentials: { username, password in
                do {
                    let response = try await handleRequest(
                        for: makeRequest(.credentials(.init(username: username, password: password))),
                        decodingTo: Identity.Authentication.Response.self
                    )

                    @Dependency(\.request) var request
                    guard let request else { throw Abort.requestUnavailable }

                    let accessToken = try await tokenClient.verifyAccess(response.accessToken)
                    request.auth.login(accessToken)

                    return response
                } catch {
                    throw Abort(.unauthorized)
                }
            },
            token: .init(
                access: { token in
                    @Dependency(\.tokenClient) var tokenClient
                    let currentToken = try await tokenClient.verifyAccess(token)

                    @Dependency(\.request) var request
                    guard let request else { throw Abort.requestUnavailable }
                    request.auth.login(currentToken)
                },
                refresh: { token in
                    do {
                        let response = try await handleRequest(
                            for: makeRequest(.token(.refresh(try JWT.parse(from: token)))),
                            decodingTo: Identity.Authentication.Response.self
                        )

                        @Dependency(\.request) var request
                        guard let request else { throw Abort.requestUnavailable }
                        @Dependency(\.tokenClient) var tokenClient

                        let newAccessToken = try await tokenClient.verifyAccess(response.accessToken)

                        request.auth.login(newAccessToken)

                        return response

                    } catch {
                        @Dependency(\.logger) var logger

//                        if let jwtError = error as? JWTError {
//                            logger.warning("Refresh token verification failed with JWT error: \(jwtError.localizedDescription)")
//                        } else
                        if let abort = error as? Abort {
                            logger.warning("Refresh token verification failed with status \(abort.status.code): \(abort.reason)")
                        } else {
                            logger.warning("Refresh token verification failed with error: \(error.localizedDescription)")
                        }

                        // Re-throw with more specific status if available
                        if let abort = error as? Abort {
                            throw abort
                        }

                        throw Abort(.unauthorized, reason: "Failed to refresh token")
                    }
                }
            ),
            apiKey: { apiKey in
                do {
                    return try await handleRequest(
                        for: makeRequest(.apiKey(.init(token: apiKey))),
                        decodingTo: Identity.Authentication.Response.self
                    )
                } catch {
                    throw Abort(.unauthorized)
                }
            }
        )
    }
}
