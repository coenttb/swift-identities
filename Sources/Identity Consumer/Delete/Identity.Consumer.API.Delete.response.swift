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

extension Identity.Deletion.API {
    public static func response(
        delete: Identity.Deletion.API
    ) async throws -> Server.Response {
        // swiftlint:disable:previous typed_throws_required

        @Dependency(\.identity) var identity
        let client = identity.delete.client

        switch delete {
        case .request(let request):
            do {
                try await client.request(request)
                return try Server.Response.json(success: true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to delete account")
            }

        case .cancel:
            do {
                try await client.cancel()
                return try Server.Response.json(success: true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to cancel account deletion")
            }

        case .confirm:
            do {
                try await client.confirm()
                return try Server.Response.json(success: true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to confirm account deletion")
            }
        }
    }
}
