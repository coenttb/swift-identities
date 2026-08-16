//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 06/02/2025.
//

import Dependencies
import IdentitiesTypes
import Identity_Shared
import JWT
import Server_Vapor
import Vapor

extension Identity.Consumer {
    public struct CredentialsAuthenticator: AsyncBasicAuthenticator {

        public init() {}

        public func authenticate(
            basic: BasicAuthorization,
            for request: Request
        ) async throws {
            // swiftlint:disable:previous typed_throws_required
            try await withDependencies {
                $0.vapor.request = request
            } operation: {
                @Dependency(\.identity) var identity
                _ = try await identity.authenticate.client.credentials(
                    .init(
                        email: try .init(basic.username),
                        password: basic.password
                    )
                )
            }
        }
    }
}
