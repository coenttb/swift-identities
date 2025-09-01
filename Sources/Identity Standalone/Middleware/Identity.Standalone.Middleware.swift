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
    /// This provides authentication and authorization middleware for standalone deployments,
    /// combining the capabilities of both Provider and Consumer middleware.
    public struct Middleware {
        /// Token authenticator for JWT-based authentication
        public let tokenAuthenticator: TokenAuthenticator
        
        /// Credentials authenticator for username/password authentication
        public let credentialsAuthenticator: CredentialsAuthenticator
        
        public init(
            tokenAuthenticator: TokenAuthenticator = .init(),
            credentialsAuthenticator: CredentialsAuthenticator = .init()
        ) {
            self.tokenAuthenticator = tokenAuthenticator
            self.credentialsAuthenticator = credentialsAuthenticator
        }
    }
}