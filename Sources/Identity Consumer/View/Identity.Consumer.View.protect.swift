//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 07/02/2025.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Consumer.View {
    package static func protect<Authenticatable: Vapor.Authenticatable>(
        view: Identity.Consumer.View,
        with type: Authenticatable.Type
    ) async throws {
        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }

        switch view {
        case .create:
            if request.auth.has(type) { throw Abort(.forbidden) }

        case .delete:
            try request.auth.require(type)

        case .authenticate(let authenticate):
            switch authenticate {
            case .credentials:
                if request.auth.has(type) { throw Abort(.forbidden) }
            }

        case .logout:
            if !request.auth.has(type) {
                throw Abort(.forbidden)
            }

        case .password(let password):
            switch password {
            case .reset:
                break

            case .change:
                try request.auth.require(type)
            }

        case .email(.change(.request)):
            try request.auth.require(type)

            guard let requestToken = request.cookies.reauthorizationToken?.string
            else { throw Abort(.internalServerError) }

            @Dependency(\.tokenClient) var tokenClient
            _ = try await tokenClient.verifyReauthorization(requestToken)

        case .email:
            try request.auth.require(type)
        }
    }
}
