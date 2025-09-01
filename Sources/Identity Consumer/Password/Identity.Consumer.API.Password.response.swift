//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Consumer.API.Password {
    public static func response(
        password: Identity.Consumer.API.Password
    ) async throws -> Response {

        @Dependency(\.identity.consumer.client) var client

        switch password {
        case .reset(let reset):
            switch reset {
            case .request(let request):
                do {
                    try await client.password.reset.request(request)
                    return Response.success(true)
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to request password reset")
                }

            case .confirm(let confirm):
                do {
                    try await client.password.reset.confirm(confirm)
                    return Response.success(true)
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to confirm password reset")
                }
            }
        case .change(let change):
            switch change {
            case .request(let request):
                do {
                    try await client.password.change.request(request)
                    return Response.success(true)
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to request password change")
                }
            }
        }
    }
}
