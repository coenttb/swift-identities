//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 06/02/2025.
//

import Identity_Shared
import ServerFoundationVapor
import IdentitiesTypes
import JWT

extension Identity.Consumer {
    public struct CredentialsAuthenticator: AsyncBasicAuthenticator {

        public init() {}

        public func authenticate(
            basic: BasicAuthorization,
            for request: Request
        ) async throws {
            try await withDependencies {
                $0.request = request
            } operation: {
                @Dependency(\.identity.consumer.client) var client
                _ = try await client.authenticate.credentials(
                    .init(
                        email: try .init(basic.username),
                        password: basic.password
                    )
                )
            }
        }
    }
}
