//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/02/2025.
//

import Dependencies
import IdentitiesTypes
import Server_Vapor
import Vapor

import enum Server.Server

extension Identity.Email.API {
    public static func response(
        email: Identity.Email.API
    ) async throws -> Server.Response {
        @Dependency(\.identity) var identity
        let client = identity.email.change.client

        switch email {
        case .change(let change):
            switch change {
            case .request(let request):
                do {
                    let data = try await client.request(request)
                    switch data {
                    case .success:
                        return try Server.Response.json(success: true)

                    case .requiresReauthentication:
                        return try Server.Response.json(success: false, message: "Requires reauthorization")
                    }
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to request email change")
                }

            case .confirm(let confirm):
                do {
                    let identityEmailChangeConfirmResponse = try await client.confirm(confirm)

                    return try Server.Response.json(success: true)
                        .withTokens(for: identityEmailChangeConfirmResponse)
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to confirm email change")
                }
            }
        }
    }
}
