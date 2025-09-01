//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 06/02/2025.
//

import Identity_Shared
import Dependencies
import EmailAddress
import JWT
@preconcurrency import Vapor

extension Identity.Provider {
    public struct CredentialsAuthenticator: AsyncBasicAuthenticator {

        @Dependency(\.identity.provider.client) var client

        public init() {}

        public func authenticate(
            basic: BasicAuthorization,
            for request: Request
        ) async throws {
            do {
                try await withDependencies {
                    $0.request = request
                } operation: {
                    _ = try await client.authenticate.credentials(username: basic.username, password: basic.password)
                }
            } catch {

            }
        }
    }
}
