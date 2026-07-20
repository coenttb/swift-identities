//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import Dependencies
import IdentitiesTypes
import Server_Vapor
import Vapor
import enum Server.Server

extension Identity.Creation.API {
    public static func response(
        create: Identity.Creation.API
    ) async throws -> Server.Response {

        @Dependency(\.identity) var identity
        let client = identity.create.client

        switch create {
        case .request(let request):
            do {
                try await client.request(request)
                return try Server.Response.json(success: true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to request account creation")
            }

        case .verify(let verify):
            do {
                try await client.verify(email: verify.email, token: verify.token)
                return try Server.Response.json(success: true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to verify account creation")
            }
        }
    }
}
