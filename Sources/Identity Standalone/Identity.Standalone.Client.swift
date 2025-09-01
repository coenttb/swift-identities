//
//  Identity.Standalone.Client.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Foundation
import IdentitiesTypes
import Dependencies
import DependenciesMacros

extension Identity.Standalone {
    /// Extended client for standalone identity operations with profile management.
    ///
    /// This client extends the base Identity.Client with additional profile
    /// management capabilities that are only available in Standalone deployments.
    public struct Client: Sendable {
        /// Base identity client with all standard operations
        public var identity: Identity.Client
        
        /// Profile management operations (Standalone only)
        public var profile: Identity.Standalone.Client.Profile
        
        public init(
            identity: Identity.Client,
            profile: Identity.Standalone.Client.Profile = .init()
        ) {
            self.identity = identity
            self.profile = profile
        }
    }
}