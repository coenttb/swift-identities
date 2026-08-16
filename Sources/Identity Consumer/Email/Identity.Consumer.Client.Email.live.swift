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

extension Identity.Email.Change.Client {
    public static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Email.Change.API) throws -> URLRequest
            // swiftlint:disable:previous typed_throws_required
    ) -> Self {
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest

        return Identity.Email.Change.Client(
            request: { newEmail throws(Identity.Email.Change.Client.Error) in
                do {
                    return try await handleRequest(
                        for: makeRequest(.request(.init(newEmail: newEmail))),
                        decodingTo: Identity.Email.Change.Request.Result.self
                    )
                } catch {
                    throw .request(reason: "\(error)")
                }
            },
            confirm: { token throws(Identity.Email.Change.Client.Error) in
                do {
                    return try await handleRequest(
                        for: makeRequest(.confirm(.init(token: token))),
                        decodingTo: Identity.Email.Change.Confirmation.Response.self
                    )
                } catch {
                    throw .confirm(reason: "\(error)")
                }
            }
        )
    }
}
