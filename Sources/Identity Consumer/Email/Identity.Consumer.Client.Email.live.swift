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

extension Identity.Consumer.Client.Email {
    public static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Consumer.API.Email) throws -> URLRequest
    ) -> Self {
        @Dependency(\.identity.consumer.client) var client
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest

        return Identity.Consumer.Client.Email(
            change: .init(
                request: { newEmail in

                    do {
                        return try await handleRequest(
                            for: makeRequest(.change(.request(.init(newEmail: newEmail)))),
                            decodingTo: Identity.Email.Change.Request.Result.self
                        )
                    } catch {
                        throw Abort(.unauthorized)
                    }
                },
                confirm: { token in
                    do {
                        return try await handleRequest(
                            for: makeRequest(.change(.confirm(.init(token: token)))),
                            decodingTo: Identity.Email.Change.Confirmation.Response.self
                        )

                    } catch {
                        throw Abort(.internalServerError)
                    }
                }
            )
        )
    }
}
