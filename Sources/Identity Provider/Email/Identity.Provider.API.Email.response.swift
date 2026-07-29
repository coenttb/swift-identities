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

import struct Vapor.Abort

extension Identity.Email.API {
    package static func providerResponse(
        email: Identity.Email.API
    ) async throws -> Server.Response {

        @Dependency(\.identity) var identity

        switch email {
        case .change(let change):
            switch change {
            case .request(let request):
                do {
                    let data = try await identity.email.change.request(request)

                    return try Server.Response.json(success: true, data: data)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.error(
                        "Failed to request email change. Error: \(String(describing: error))"
                    )
                    throw Abort(.internalServerError, reason: "Failed to request email change")
                }

            case .confirm(let confirm):
                do {
                    let data = try await identity.email.change.confirm(confirm)

                    @Dependencies.Dependency(\.logger) var logger
                    logger.info("Email change confirmed for new email")

                    return try Server.Response.json(success: true, data: data)
                } catch {
                    @Dependencies.Dependency(\.logger) var logger
                    logger.error(
                        "Failed to confirm email change. Error: \(String(describing: error))"
                    )
                    throw Abort(.internalServerError, reason: "Failed to confirm email change")
                }
            }
        }
    }
}
