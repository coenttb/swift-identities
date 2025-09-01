//
//  Identity.Consumer.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 28/01/2025.
//

import Foundation
import IdentitiesTypes

extension Identity {
    /// A namespace for client-side identity management operations and user sessions.
    ///
    /// The `Consumer` namespace provides types and interfaces for client applications
    /// to interact with identity services, including:
    /// - Authentication flows (login, logout)
    /// - Identity management (creation, deletion)
    /// - Profile operations (email and password changes)
    /// - View routing for identity-related UI flows
    ///
    /// The namespace is designed to work in tandem with the `Provider` namespace,
    /// sharing common types through `Identity_Shared` to ensure consistency in
    /// client-server communication.
    public enum Consumer {}
}
