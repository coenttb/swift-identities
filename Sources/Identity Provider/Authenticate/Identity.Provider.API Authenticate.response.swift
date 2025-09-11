//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2024.
//

import ServerFoundationVapor
import Foundation
import IdentitiesTypes

extension Identity.Provider.API.Authenticate {
    package static func response(
        authenticate: Identity.Provider.API.Authenticate
    ) async throws -> Response {

        @Dependency(\.identity.provider.client) var identity

        switch authenticate {
        case .credentials(let credentials):
            let identityAuthenticationResponse = try await identity.authenticate.credentials(credentials)
            return Response.success(true, data: identityAuthenticationResponse)

        case .token(let token):
            switch token {
            case .access(let access):
                try await identity.authenticate.token.access(access)
                return Response.success(true)

            case .refresh(let refresh):
                let identityAuthenticationResponse = try await identity.authenticate.token.refresh(refresh)
                return Response.success(true, data: identityAuthenticationResponse)
            }
        case .apiKey(let apiKey):
            let identityAuthenticationResponse = try await identity.authenticate.apiKey(apiKey)
            return Response.success(true, data: identityAuthenticationResponse)

        }
    }
}
