//
//  Identity.Standalone.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Foundation
import IdentitiesTypes

extension Identity {
    /// A namespace for standalone identity management that combines provider and consumer functionality.
    ///
    /// The `Standalone` namespace provides a complete identity solution for single-server deployments,
    /// combining the database operations from Backend with the UI from Views. This is ideal for
    /// applications that don't need distributed identity management but want a full-featured
    /// authentication and authorization system.
    ///
    /// Standalone includes:
    /// - Direct database access (like Provider)
    /// - Local session management (like Consumer)
    /// - Complete UI views for all identity operations
    /// - Simplified configuration for single-server setups
    ///
    /// This approach is perfect for:
    /// - Small to medium applications
    /// - Monolithic architectures
    /// - Development and testing environments
    /// - Applications that don't need federated identity
    public enum Standalone {}
}