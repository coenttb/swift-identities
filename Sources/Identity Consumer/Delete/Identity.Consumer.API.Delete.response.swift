//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Consumer.API.Delete {
    public static func response(
        delete: Identity.Consumer.API.Delete
    ) async throws -> Response {

        @Dependency(\.identity.consumer.client) var client

        switch delete {
        case .request(let request):
            do {
                try await client.delete.request(request)
                return Response.success(true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to delete account")
            }

        case .cancel:
            do {
                try await client.delete.cancel()
                return Response.success(true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to cancel account deletion")
            }

        case .confirm:
            do {
                try await client.delete.confirm()
                return Response.success(true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to confirm account deletion")
            }
        }
    }
}
