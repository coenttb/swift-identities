//
//  Identity.Frontend.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Foundation
import IdentitiesTypes

extension Identity {
    /// A namespace for shared frontend functionality used by both Consumer and Standalone.
    ///
    /// The `Frontend` namespace provides common API and View response handling logic
    /// that can be used by both Consumer (remote identity) and Standalone (local identity).
    /// This eliminates code duplication and ensures consistent behavior across different
    /// deployment models.
    ///
    /// Frontend includes:
    /// - API response handlers that accept a client parameter
    /// - View response handlers with shared rendering logic
    /// - Protection middleware for authentication checks
    /// - Cookie and session management utilities
    ///
    /// Both Consumer and Standalone delegate to Frontend, passing their respective
    /// clients (remote or local) and configurations.
    public enum Frontend {}
}