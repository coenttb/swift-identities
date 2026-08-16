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

extension Identity.Deletion.Client {
    public static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Deletion.API) throws -> URLRequest
    ) -> Self {
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest

        return .init(
            request: { reauthToken throws(Identity.Deletion.Client.Error) in
                do {
                    try await handleRequest(
                        for: makeRequest(.request(.init(reauthToken: reauthToken)))
                    )
                } catch {
                    throw .request(reason: "\(error)")
                }
            },
            cancel: { () throws(Identity.Deletion.Client.Error) in
                do {
                    try await handleRequest(for: makeRequest(.cancel))
                } catch {
                    throw .cancel(reason: "\(error)")
                }
            },
            confirm: { () throws(Identity.Deletion.Client.Error) in
                do {
                    try await handleRequest(for: makeRequest(.confirm))
                } catch {
                    throw .confirm(reason: "\(error)")
                }
            }
        )
    }
}
