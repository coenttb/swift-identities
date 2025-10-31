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

extension Identity.Creation.Client {
    public static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Creation.API) throws -> URLRequest
    ) -> Self {
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest

        return .init(
            request: { email, password in
                do {
                    try await handleRequest(
                        for: makeRequest(.request(.init(email: email, password: password)))
                    )
                } catch {
                    throw Abort(.internalServerError)
                }
            },
            verify: { email, token in
                do {
                    try await handleRequest(
                        for: makeRequest(.verify(.init(token: token, email: email)))
                    )
                } catch {
                    throw Abort(.internalServerError)
                }
            }
        )
    }
}
