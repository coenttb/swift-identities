//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2024.
//

import Dependencies
import Foundation
import IdentitiesTypes
import Logger_Dependencies
import Logging
import Server
import Server_Vapor
import Vapor

extension Identity.Password.API {
    package static func providerResponse(
        password: Identity.Password.API
    ) async throws -> Server.Response {

        @Dependency(\.identity) var identity

        switch password {
        case .reset(let reset):
            switch reset {
            case .request(let request):
                do {
                    try await identity.password.reset.request(request)
                    return try Server.Response.json(success: true)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.error(
                        "Failed to request password reset. Error: \(String(describing: error))"
                    )
                    throw Abort(.internalServerError, reason: "Failed to request password reset")
                }
            case .confirm(let confirm):
                do {
                    try await identity.password.reset.confirm(confirm)

                    return try Server.Response.json(success: true)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.error(
                        "Failed to reset password. Error: \(String(describing: error))"
                    )
                    throw Abort(.internalServerError, reason: "Failed to reset password")
                }
            }
        case .change(let change):
            switch change {
            case .request(change: let request):
                do {
                    try await identity.password.change.request(request)
                    return try Server.Response.json(success: true)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.error(
                        "Failed to change password. Error: \(String(describing: error))"
                    )
                    throw Abort(.internalServerError, reason: "Failed to change password")
                }
            }
        }
    }
}
