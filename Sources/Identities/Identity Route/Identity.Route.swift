//
//  Identity.Route.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 07/02/2025.
//

import CasePaths
import Dependencies
import Foundation
import Swift_Web

extension Identity {
    /// Routes available in the consumer-side identity system.
    ///
    /// The `Route` enum defines two primary categories of routes:
    /// - API routes for server communication
    /// - View routes for UI navigation
    ///
    /// Example usage:
    /// ```swift
    /// switch route {
    /// case .api(let api):
    ///     // Handle API requests like authentication
    /// case .view(let view):
    ///     // Handle view transitions like showing login form
    /// }
    /// ```
    @CasePathable
    @dynamicMemberLookup
    public enum Route: Equatable, Sendable {
        /// Routes to API endpoints for server communication
        case api(Identity.API)
        /// Routes to view states for UI navigation
        case view(Identity.View)
    }
}

extension Identity.Route {
    /// A type-safe router for mapping URLs to consumer identity routes.
    ///
    /// The router handles two main path structures:
    /// - `/api/*` for API endpoints
    /// - `/*` for view navigation
    ///
    /// Example URL patterns:
    /// ```
    /// /api/authenticate          -> .api(.authenticate)
    /// /login                     -> .view(.authenticate(.credentials))
    /// /create/request           -> .view(.create(.request))
    /// ```
    public struct Router: ParserPrinter, Sendable {

        public init() {}

        public var body: some URLRouting.Router<Identity.Route> {
            OneOf {

                URLRouting.Route(.case(Identity.Route.api)) {
                    Path.api
                    Identity.API.Router()
                }

                URLRouting.Route(.case(Identity.Route.view)) {
                    Identity.View.Router()
                }
            }
        }
    }
}

extension Identity.Route.Router: TestDependencyKey {
    /// A test implementation of the consumer route router.
    ///
    /// This provides a parser-printer for use in test environments to verify
    /// routing logic without requiring a full client implementation.
    public static let testValue: AnyParserPrinter<URLRequestData, Identity.Route> = Identity.Route.Router().eraseToAnyParserPrinter()
}
