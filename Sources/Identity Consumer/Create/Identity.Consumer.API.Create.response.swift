//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Consumer.API.Create {
    public static func response(
        create: Identity.Consumer.API.Create
    ) async throws -> Response {

        @Dependency(\.identity.consumer.client) var client

        switch create {
        case .request(let request):
            do {
                try await client.create.request(request)
                return Response.success(true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to request account creation")
            }

        case .verify(let verify):
            do {
                try await client.create.verify(email: verify.email, token: verify.token)
                return Response.success(true)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to verify account creation")
            }
        }
    }
}
