//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2024.
//

import ServerFoundationVapor
import Foundation
import IdentitiesTypes

extension Identity.Password.API {
    package static func providerResponse(
        password: Identity.Password.API
    ) async throws -> Response {

        @Dependency(\.identity) var identity

        switch password {
        case .reset(let reset):
            switch reset {
            case let .request(request):
                do {
                    try await identity.password.reset.request(request)
                    return Response.success(true)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.log(.error, "Failed to request password reset. Error: \(String(describing: error))")
                    throw Abort(.internalServerError, reason: "Failed to request password reset")
                }
            case let .confirm(confirm):
                do {
                    try await identity.password.reset.confirm(confirm)

                    return Response.success(true)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.log(.error, "Failed to reset password. Error: \(String(describing: error))")
                    throw Abort(.internalServerError, reason: "Failed to reset password")
                }
            }
        case .change(let change):
            switch change {
            case let .request(change: request):
                do {
                    try await identity.password.change.request(request)
                    return Response.success(true)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.log(.error, "Failed to change password. Error: \(String(describing: error))")
                    throw Abort(.internalServerError, reason: "Failed to change password")
                }
            }
        }
    }
}
