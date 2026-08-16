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

extension Identity.Password.Client {
    public static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Password.API) throws -> URLRequest
            // swiftlint:disable:previous typed_throws_required
    ) -> Self {

        @Dependency(URLRequest.Handler.Identity.self) var handleRequest
        return .init(
            reset: .init(
                request: { email throws(Identity.Password.Reset.Client.Error) in
                    do {
                        try await handleRequest(
                            for: makeRequest(.reset(.request(.init(email: email))))
                        )
                    } catch {
                        throw .request(reason: "\(error)")
                    }
                },
                confirm: { token, newPassword throws(Identity.Password.Reset.Client.Error) in
                    do {
                        try await handleRequest(
                            for: makeRequest(
                                .reset(.confirm(.init(token: token, newPassword: newPassword)))
                            )
                        )
                    } catch {
                        throw .confirm(reason: "\(error)")
                    }
                }
            ),
            change: .init(
                request: {
                    currentPassword,
                    newPassword throws(Identity.Password.Change.Client.Error) in
                    do {
                        try await handleRequest(
                            for: makeRequest(
                                .change(
                                    .request(
                                        .init(
                                            currentPassword: currentPassword,
                                            newPassword: newPassword
                                        )
                                    )
                                )
                            )
                        )
                    } catch {
                        throw .request(reason: "\(error)")
                    }
                }
            )
        )
    }
}
