//
//  OAuthProviderRegistry.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2025.
//

import Foundation
import IdentitiesTypes

/// Registry for OAuth providers
public actor OAuthProviderRegistry {
    private var providers: [String: any Identity.OAuth.Provider] = [:]
    
    public init() {}
    
    /// Register an OAuth provider
    public func register(_ provider: any Identity.OAuth.Provider) {
        providers[provider.identifier] = provider
    }
    
    /// Get a registered provider by identifier
    public func provider(for identifier: String) -> (any Identity.OAuth.Provider)? {
        providers[identifier]
    }
    
    /// Get all registered providers
    public func allProviders() -> [any Identity.OAuth.Provider] {
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