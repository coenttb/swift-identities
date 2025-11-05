//
//  Identity.Provider.API.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 05/02/2025.
//

import Foundation
import IdentitiesTypes

extension Identity.Provider {
    /// A type alias providing access to the shared API interface for identity provider services.
    ///
    /// This alias maps the provider-side API to the shared identity API definition,
    /// ensuring consistent API types between server and client. It provides endpoints for:
    /// - Authentication verification
    /// - Identity management operations
    /// - Token issuance and validation
    /// - Security policy enforcement
    ///
    /// Example usage:
    /// ```swift
    /// switch api {
    /// case .authenticate(let authenticate):
    ///     // Validate credentials and issue tokens
    /// case .create(let create):
    ///     // Handle new identity creation request
    /// }
    /// ```
    ///
    /// By using the shared API definition, the provider maintains a contract
    /// with consumers while implementing the server-side business logic and
    /// security measures. This ensures consistency in:
    /// - Request/response formats
    /// - Authentication flows
    /// - Error handling
    /// - Data validation rules
    public typealias API = Identity.API
}
