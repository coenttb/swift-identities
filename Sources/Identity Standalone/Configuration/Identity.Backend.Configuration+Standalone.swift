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
import URLRouting

extension Identity.Backend.Configuration: DependencyKey {
    /// In Standalone mode, Backend configuration is extracted from Standalone configuration
    public static var liveValue: Self {
        @Dependency(Identity.Standalone.Configuration.self) var configuration

        return Self(
            jwt: configuration.jwt,
            router: configuration.router.authentication.eraseToAnyParserPrinter(),
            email: configuration.email,
            tokenEnrichment: configuration.tokenEnrichment,
//            mfa: configuration.mfa,
//            oauth: configuration.oauth
        )
    }
}
