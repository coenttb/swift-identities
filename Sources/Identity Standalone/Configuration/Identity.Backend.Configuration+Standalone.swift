//
//  Identity.Backend.Configuration+Standalone.swift
//  swift-identities
//
//  Standalone implements the live value for Backend.Configuration
//  by extracting it from its own configuration
//

import Identity_Backend
import Identity_Shared
import Dependencies

extension Identity.Backend.Configuration: DependencyKey {
    /// In Standalone mode, Backend configuration is extracted from Standalone configuration
    public static var liveValue: Self {
        @Dependency(Identity.Standalone.Configuration.self) var configuration
        @Dependency(\.identity) var identity

        let emailConfig = configuration.email ?? .noop

        return Self(
            jwt: configuration.jwt,
            router: identity.authenticate.router,
            email: emailConfig,
            tokenEnrichment: configuration.tokenEnrichment,
            mfa: configuration.mfa,
            oauth: configuration.oauth
        )
    }
}
