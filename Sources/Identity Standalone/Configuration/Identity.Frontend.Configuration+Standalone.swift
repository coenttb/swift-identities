//
//  Identity.Frontend.Configuration+Standalone.swift
//  swift-identities
//
//  Standalone implements the live value for Frontend.Configuration
//  by extracting it from its own configuration
//

import Identity_Frontend
import Dependencies

extension Identity.Frontend.Configuration: DependencyKey {
    /// In Standalone mode, Frontend configuration is extracted from Standalone configuration
    public static var liveValue: Self {
        @Dependency(Identity.Standalone.Configuration.self) var configuration
        @Dependency(\.identity) var identity

        // Extract Frontend-specific fields from Standalone configuration
        return Self(
            baseURL: configuration.baseURL,
            identity: identity,
            jwt: configuration.jwt,
            cookies: configuration.cookies,
            branding: configuration.branding,
            navigation: configuration.navigation,
            redirect: configuration.redirect,
            rateLimiters: configuration.rateLimiters,
            currentUserName: configuration.currentUserName,
            canonicalHref: configuration.canonicalHref,
            hreflang: configuration.hreflang
        )
    }
}
