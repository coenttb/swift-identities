//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/02/2025.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Consumer.API.Email.Change {
    public static func response(
        email: Identity.Consumer.API.Email
    ) async throws -> Response {
        @Dependency(\.identity.consumer.client) var client

        switch email {
        case .change(let change):
            switch change {
            case .request(let request):
                do {
                    let data = try await client.email.change.request(request)
                    switch data {
                    case .success:
                        return Response.success(true)

                    case .requiresReauthentication:
                        return Response.success(false, message: "Requires reauthorization")
                    }
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to request email change")
                }

            case .confirm(let confirm):
                do {
                    let identityEmailChangeConfirmResponse = try await client.email.change.confirm(confirm)

                    return Response.success(true)
                        .withTokens(for: identityEmailChangeConfirmResponse)
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to confirm email change")
                }
            }
        }
    }
}
