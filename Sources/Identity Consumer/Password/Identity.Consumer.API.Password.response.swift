//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Password.API {
    public static func response(
        password: Identity.Password.API
    ) async throws -> Response {

        @Dependency(\.identity) var identity

        switch password {
        case .reset(let reset):
            switch reset {
            case .request(let request):
                do {
                    try await identity.password.reset.client.request(request)
                    return Response.success(true)
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to request password reset")
                }

            case .confirm(let confirm):
                do {
                    try await identity.password.reset.client.confirm(confirm)
                    return Response.success(true)
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to confirm password reset")
                }
            }
        case .change(let change):
            switch change {
            case .request(let request):
                do {
                    try await identity.password.change.client.request(request)
                    return Response.success(true)
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to request password change")
                }
            }
        }
    }
}
