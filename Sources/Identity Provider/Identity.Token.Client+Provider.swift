//
//  Identity.Token.Client+Provider.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 18/08/2025.
//

import Foundation
import Dependencies
import IdentitiesTypes
import Identity_Backend

extension Identity.Provider {
    /// JWT Token Client configuration specifically for Provider API services.
    /// Uses the unified configuration from Backend module.
    public struct TokenClientConfiguration {
        
        /// Production configuration for Provider API services.
        /// Has stricter security settings than Standalone.
        public static func production() -> Identity.Token.Client {
            Identity.Token.Client.ProviderConfiguration.production()
        }
        
        /// Development configuration for Provider API testing.
        public static func development() -> Identity.Token.Client {
            Identity.Token.Client.ProviderConfiguration.development()
        }
    }
}

// Provider doesn't provide a default DependencyKey implementation
// because it should be explicitly configured based on environment
// Users should set it up like:
//
// extension Identity.Token.Client: @retroactive DependencyKey {
//     public static var liveValue: Self {
//         #if DEBUG
//         return Identity.Provider.TokenClientConfiguration.development()
//         #else
//         return Identity.Provider.TokenClientConfiguration.production()
//         #endif
//     }
// }
