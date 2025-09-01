//
//  Identity.Consumer.Client.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 05/02/2025.
//

import Foundation
import IdentitiesTypes

extension Identity.Consumer {
    /// A type alias providing access to the shared client interface for identity operations.
    ///
    /// This alias maps the consumer-side client to the shared identity client definition,
    /// providing a consistent interface for:
    /// - Authentication operations (login, logout)
    /// - Identity management (create, delete)
    /// - Profile updates (email, password)
    /// - Session management
    ///
    /// Example usage:
    /// ```swift
    /// let client = Identity.Consumer.Client(...)
    ///
    /// // Authenticate user
    /// try await client.login(
    ///     username: "user@example.com",
    ///     password: "password123"
    /// )
    /// ```
    ///
    /// By using the shared client definition, consumers have access to a complete
    /// set of identity management operations that are compatible with the provider's
    /// implementation.
    public typealias Client = Identity.Client
}
