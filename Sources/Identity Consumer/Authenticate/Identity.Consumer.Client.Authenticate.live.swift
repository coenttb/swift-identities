//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 11/02/2025.
//

import Dependencies
import EmailAddress
import Foundation
import IdentitiesTypes
import Identity_Shared
import JWT
import Logger_Dependencies
import Logging
import Server_Vapor
import Throttling
import URLRequestHandler
import Vapor

extension Identity.Authentication.Client {
    package static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Authentication.API) throws -> URLRequest
            // swiftlint:disable:previous typed_throws_required
    ) -> Self {
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest
        @Dependency(\.tokenClient) var tokenClient

        return .init(
            credentials: { username, password throws(Identity.Authentication.Client.Error) in
                do {
                    let response = try await handleRequest(
                        for: makeRequest(
                            .credentials(.init(username: username, password: password))
                        ),
                        decodingTo: Identity.Authentication.Response.self
                    )

                    @Dependency(\.vapor.request) var request
                    guard let request else { throw Abort.requestUnavailable }

                    let accessToken = try await tokenClient.verifyAccess(response.accessToken)
                    request.auth.login(accessToken)

                    return response
                } catch {
                    throw .credentials(reason: "\(error)")
                }
            },
            apiKey: { apiKey throws(Identity.Authentication.Client.Error) in
                do {
                    return try await handleRequest(
                        for: makeRequest(.apiKey(.init(token: apiKey))),
                        decodingTo: Identity.Authentication.Response.self
                    )
                } catch {
                    throw .apiKey(reason: "\(error)")
                }
            }
        )
    }
}

extension Identity.Authentication.Token.Client {
    package static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Authentication.API) throws -> URLRequest
            // swiftlint:disable:previous typed_throws_required
    ) -> Self {
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest
        @Dependency(\.tokenClient) var tokenClient

        return .init(
            access: { token throws(Identity.Authentication.Token.Client.Error) in
                do {
                    @Dependency(\.tokenClient) var tokenClient
                    let currentToken = try await tokenClient.verifyAccess(token)

                    @Dependency(\.vapor.request) var request
                    guard let request else { throw Abort.requestUnavailable }
                    request.auth.login(currentToken)
                } catch {
                    throw .access(reason: "\(error)")
                }
            },
            refresh: { token throws(Identity.Authentication.Token.Client.Error) in
                do {
                    let response = try await handleRequest(
                        for: makeRequest(.token(.refresh(try JWT.parse(from: token)))),
                        decodingTo: Identity.Authentication.Response.self
                    )

                    @Dependency(\.vapor.request) var request
                    guard let request else { throw Abort.requestUnavailable }
                    @Dependency(\.tokenClient) var tokenClient

                    let newAccessToken = try await tokenClient.verifyAccess(response.accessToken)

                    request.auth.login(newAccessToken)

                    return response

                } catch {
                    @Dependency(\.logger) var logger

                    if let abort = error as? Abort {
                        logger.warning(
                            "Refresh token verification failed with status \(abort.status.code): \(abort.reason)"
                        )
                    } else {
                        logger.warning(
                            "Refresh token verification failed with error: \(error.localizedDescription)"
                        )
                    }

                    throw .refresh(reason: "\(error)")
                }
            }
        )
    }
}
