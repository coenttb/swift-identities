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
import Server_Vapor
import Throttling
import URLRequestHandler
import Vapor

extension Identity.Creation.Client {
    public static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Creation.API) throws -> URLRequest
    ) -> Self {
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest

        return .init(
            request: { email, password throws(Identity.Creation.Client.Error) in
                do {
                    try await handleRequest(
                        for: makeRequest(.request(.init(email: email, password: password)))
                    )
                } catch {
                    throw .request(reason: "\(error)")
                }
            },
            verify: { email, token throws(Identity.Creation.Client.Error) in
                do {
                    try await handleRequest(
                        for: makeRequest(.verify(.init(token: token, email: email)))
                    )
                } catch {
                    throw .verify(reason: "\(error)")
                }
            }
        )
    }
}
