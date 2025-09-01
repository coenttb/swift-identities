//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2024.
//

import ServerFoundationVapor
import Foundation
import IdentitiesTypes

extension Identity.Provider.API.Create {
    package static func response(
        create: Identity.Provider.API.Create
    ) async throws -> Response {

        @Dependency(\.identity.provider.client) var client
        @Dependency(\.logger) var logger

        switch create {
        case .request(let request):
            do {
                try await client.create.request(request)
                return Response.success(true)
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
                try await client.create.verify(verify)
                return Response.success(true, status: .created)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to verify account creation. Error: \(String(describing: error))")
            }
        }
    }
}
