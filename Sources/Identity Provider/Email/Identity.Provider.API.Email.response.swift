//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2024.
//

import ServerFoundationVapor
import Foundation
import IdentitiesTypes

extension Identity.Provider.API.Email {
    package static func response(
        email: Identity.Provider.API.Email
    ) async throws -> Response {

        @Dependency(\.identity.provider.client) var client

        switch email {
        case .change(let change):
            switch change {
            case .request(let request):
                do {
                    let data = try await client.email.change.request(request)

                    return Response.success(true, data: data)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.log(.error, "Failed to request email change. Error: \(String(describing: error))")
                    throw Abort(.internalServerError, reason: "Failed to request email change")
                }

            case .confirm(let confirm):
                do {
                    let data = try await client.email.change.confirm(confirm)

                    @Dependencies.Dependency(\.logger) var logger
                    logger.log(.info, "Email change confirmed for new email")

                    return Response.success(true, data: data)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.log(.error, "Failed to confirm email change. Error: \(String(describing: error))")
                    throw Abort(.internalServerError, reason: "Failed to confirm email change")
                }
            }
        }
    }
}
