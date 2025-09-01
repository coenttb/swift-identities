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

extension Identity.Consumer.Client.Password {
    public static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Consumer.API.Password) throws -> URLRequest
    ) -> Self {

        @Dependency(\.identity.consumer.client) var client
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest
        return .init(
            reset: .init(
                request: { email in
                    do {
                        try await handleRequest(
                            for: makeRequest(.reset(.request(.init(email: email))))
                        )
                    } catch {
                        throw Abort(.unauthorized)
                    }
                },
                confirm: { token, newPassword in
                    do {
                        try await handleRequest(
                            for: makeRequest(.reset(.confirm(.init(token: token, newPassword: newPassword))))
                        )
                    } catch {
                        throw Abort(.internalServerError)
                    }
                }
            ),
            change: .init(
                request: { currentPassword, newPassword in
                    do {
                        try await handleRequest(
                            for: makeRequest(.change(.request(change: .init(currentPassword: currentPassword, newPassword: newPassword))))
                        )
                    } catch {
                        throw Abort(.unauthorized)
                    }
                }
            )
        )
    }
}
