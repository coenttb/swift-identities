//
//  Identity.Standalone.Middleware.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Standalone {
    /// Middleware configuration for standalone identity management.
    ///
    /// This provides authentication and authorization middleware for standalone deployments.
    /// Note: Credentials authentication is handled at the route level, not in middleware.
    public struct Middleware {
        /// Token authenticator for JWT-based authentication
        public let tokenAuthenticator: TokenAuthenticator
        
        public init(
            tokenAuthenticator: TokenAuthenticator = .init()
        ) {
            self.tokenAuthenticator = tokenAuthenticator
        }
    }
}