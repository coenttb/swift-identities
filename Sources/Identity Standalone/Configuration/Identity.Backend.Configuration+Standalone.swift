//
//  Identity.Backend.Configuration+Standalone.swift
//  swift-identities
//
//  Standalone implements the live value for Backend.Configuration
//  by extracting it from its own configuration
//

import Dependencies
import Identity_Backend
import Identity_Shared
import URLRouting

extension Identity.Backend.Configuration: Dependency.Key {
    /// In Standalone mode, Backend configuration is extracted from Standalone configuration
    public static var liveValue: Self {
        @Dependency(\.identityStandaloneConfiguration) var configuration

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
