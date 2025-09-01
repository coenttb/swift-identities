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

extension Identity.Consumer.Client.Delete {
    public static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Consumer.API.Delete) throws -> URLRequest
    ) -> Self {
        @Dependency(\.identity.consumer.client) var client
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest
        
        return .init(
            request: { reauthToken in
                do {
                    try await handleRequest(for: makeRequest(.request(.init(reauthToken: reauthToken))))
                } catch {
                    throw Abort(.unauthorized)
                }
            },
            cancel: {
                do {
                    try await handleRequest(for: makeRequest(.cancel))
                } catch {
                    throw Abort(.unauthorized)
                }
            },
            confirm: {
                do {
                    try await handleRequest(for: makeRequest(.confirm))
                } catch {
                    throw Abort(.unauthorized)
                }
            }
        )
    }
}
