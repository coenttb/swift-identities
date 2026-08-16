//
//  Identity.OAuth.ProviderRegistry.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2025.
//

import Foundation
import IdentitiesTypes

extension Identity.OAuth {
    /// Registry for OAuth providers
    public actor ProviderRegistry {
        private var providers: [String: any Identity.OAuth.Provider] = [:]
        // swiftlint:disable:previous no_any_protocol_existential

        public init() {}

        /// Register an OAuth provider
        public func register(_ provider: any Identity.OAuth.Provider) {
            // swiftlint:disable:previous no_any_protocol_existential
            providers[provider.identifier] = provider
        }

        /// Get a registered provider by identifier
        public func provider(for identifier: String) -> (any Identity.OAuth.Provider)? {
            // swiftlint:disable:previous no_any_protocol_existential
            providers[identifier]
        }

        /// Get all registered providers
        public func allProviders() -> [any Identity.OAuth.Provider] {
            // swiftlint:disable:previous no_any_protocol_existential
            Array(providers.values)
        }

        /// Remove a provider
        public func unregister(_ identifier: String) {
            providers.removeValue(forKey: identifier)
        }

        /// Check if a provider is registered
        public func isRegistered(_ identifier: String) -> Bool {
            providers[identifier] != nil
        }
    }
}
