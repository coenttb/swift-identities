//
//  Identity.Consumer.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 05/02/2025.
//

import Foundation
import IdentitiesTypes

extension Identity.Consumer {
    /// A type alias providing access to the shared API interface for client applications.
    ///
    /// This alias maps the consumer-side API to the shared identity API definition,
    /// ensuring consistent API types between client and server. It provides access to:
    /// - Authentication endpoints
    /// - Identity management routes
    /// - Password operations
    /// - Email management
    ///
    /// Example usage:
    /// ```swift
    /// switch api {
    /// case .authenticate(let authenticate):
    ///     // Handle request to authenticate an identity
    /// case .create(let create):
    ///     // Handle request to create an identity
    /// }
    /// ```
    ///
    /// By using the shared API definition, the consumer maintains compatibility
    /// with the identity provider's endpoint specifications and data structures.
    public typealias API = Identity.API
}
