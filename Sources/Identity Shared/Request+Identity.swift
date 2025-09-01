//
//  Request+Identity.swift
//  coenttb-identities
//
//  Provides convenient access to identity-related information in Vapor requests.
//  Uses an intermediate struct to create a clean namespace for all identity operations.
//

import ServerFoundationVapor
import IdentitiesTypes
import Foundation

extension Vapor.Request {
    /// Access identity-related information for the current request
    public var identity: IdentityContext? {
        self.auth.get(Identity.Token.Access.self).map(IdentityContext.init(token:))
    }
    
    /// Context object providing access to identity information for a request
    public struct IdentityContext {
        public let token: Identity.Token.Access

        
        /// Whether the request is authenticated
        public var isAuthenticated: Bool {
            true // If we have a context, we're authenticated
        }
        
        /// The authenticated identity's ID
        public var id: UUID {
            token.identityId
        }
        
        /// The authenticated identity's email address
        public var email: EmailAddress {
            token.email
        }
        
        /// The authenticated identity's display name (Standalone only)
        public var displayName: String {
            token.displayName
        }
        
//        /// Require authenticated identity ID or throw an unauthorized error
//        /// - Returns: The UUID of the authenticated identity
//        /// - Throws: Abort.unauthorized if not authenticated
//        public func requireId() throws -> UUID {
//            guard let id = id else {
//                throw Abort(.unauthorized, reason: "Authentication required")
//            }
//            return id
//        }
    }
}

extension Identity {
    /// Require authentication or throw an unauthorized error
    /// - Returns: The access token for the authenticated session
    /// - Throws: Abort.unauthorized if not authenticated
    public static func require() throws -> Identity.Token.Access {
        @Dependency(\.request) var request
        guard let token = request?.identity?.token
        else { fatalError()}
        return token
    }
}
