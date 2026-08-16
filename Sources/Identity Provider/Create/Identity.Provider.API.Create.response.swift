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
import Server
import Server_Vapor

import struct Vapor.Abort

extension Identity.Creation.API {
    package static func providerResponse(
        create: Identity.Creation.API
    ) async throws -> Server.Response {
        // swiftlint:disable:previous typed_throws_required

        @Dependency(\.identity) var identity
        @Dependency(\.logger) var logger

        switch create {
        case .request(let request):
            do {
                try await identity.create.request(request)
                return try Server.Response.json(success: true)
            } catch {
                throw error
            }

        //            catch let error as Abort where error.status == .tooManyRequests {
        //                throw error
        //            }
        //            catch {
        //                @Dependencies.Dependency(\.logger) var logger
        //                logger.log(.critical, "Failed to create account. Error: \(String(describing: error))")
        //
        //                throw Abort(.internalServerError, reason: "Failed to request account creation")
        //            }
        case .verify(let verify):
            do {
                try await identity.create.verify(verify)
                return try Server.Response.json(success: true, status: .created)
            } catch {
                throw Abort(
                    .internalServerError,
                    reason: "Failed to verify account creation. Error: \(String(describing: error))"
                )
            }
        }
    }
}
