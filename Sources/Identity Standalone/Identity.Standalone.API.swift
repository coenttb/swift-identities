//
//  Identity.Standalone.API.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Foundation
import IdentitiesTypes
import Server

extension Identity.Standalone {
    /// Extended API for standalone identity management.
    ///
    /// Includes all standard Identity.API endpoints plus profile management
    /// that is only available in Standalone deployments.
    @Cases
    public enum API: Equatable, Sendable {

        /// Profile management endpoints (Standalone only)
        case profile(Identity.API.Profile)
    }
}

extension Identity.Standalone.API {
    /// Router for standalone API endpoints.
    public struct Router: ParserPrinter, Sendable {

        public init() {}

        public var body: some URLRouting.Router<Identity.Standalone.API> {
            OneOf {
                // Profile routes (check first to avoid conflict with identity routes)
                URLRouting.Route(.case(Identity.Standalone.API.cases.profile)) {
                    Path { "profile" }
                    Identity.API.Profile.Router()
                }
            }
        }
    }
}
