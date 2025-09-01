//
//  Identity.Provider.Client.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 05/02/2025.
//

import Foundation
import IdentitiesTypes

extension Identity.Provider {
   /// A type alias providing access to the shared client interface for provider-side identity operations.
   ///
   /// This alias maps the provider-side client to the shared identity client definition,
   /// giving providers a consistent interface for:
   /// - Credential validation and token issuance
   /// - Identity lifecycle management
   /// - Security policy enforcement
   /// - Session monitoring and control
   ///
   /// Example usage:
   /// ```swift
   /// let client = Identity.Provider.Client(...)
   ///
   /// // Validate credentials and issue tokens
   /// let tokens = try await client.authenticate(
   ///     username: "user@example.com",
   ///     password: "password123"
   /// )
   /// ```
   ///
   /// By using the shared client definition, providers have access to a complete
   /// set of identity management operations that integrate seamlessly with consumer
   /// implementations while maintaining appropriate security boundaries and controls.
   public typealias Client = Identity.Client
}
