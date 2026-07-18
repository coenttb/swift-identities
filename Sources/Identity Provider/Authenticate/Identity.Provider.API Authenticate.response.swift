//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2024.
//

import Dependencies
import Foundation
import IdentitiesTypes
import Server
import Server_Vapor

extension Identity.Authentication.API {
    package static func providerResponse(
        authenticate: Identity.Authentication.API
    ) async throws -> Server.Response {

        @Dependency(\.identity) var identity

        switch authenticate {
        case .credentials(let credentials):
            let identityAuthenticationResponse = try await identity.authenticate.credentials(
                credentials
            )
            return try Server.Response.json(success: true, data: identityAuthenticationResponse)

        case .token(let token):
            switch token {
            case .access(let access):
                try await identity.authenticate.token.access(access)
                return try Server.Response.json(success: true)

            case .refresh(let refresh):
                let identityAuthenticationResponse = try await identity.authenticate.token.refresh(
                    refresh
                )
                return try Server.Response.json(success: true, data: identityAuthenticationResponse)
            }
        case .apiKey(let apiKey):
            let identityAuthenticationResponse = try await identity.authenticate.apiKey(
                apiKey.token
            )
            return try Server.Response.json(success: true, data: identityAuthenticationResponse)

        }
    }
}
