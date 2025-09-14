//
//  Identity.Standalone.Configuration.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Identity_Frontend

extension Identity.Standalone {
    /// Standalone uses the same configuration as Frontend.
    /// Since Standalone includes both provider and consumer functionality,
    /// it needs the full Frontend configuration including the identity.
    public typealias Configuration = Identity.Frontend.Configuration
}

extension DependencyValues {
    public var identity: Identity.Frontend.Configuration {
        get { self[Identity.Frontend.Configuration.self] }
        set { self[Identity.Frontend.Configuration.self] = newValue }
    }
}

extension Identity: @retroactive DependencyKey {
    public static var liveValue: Self {
        @Dependency(\.identity.identity) var identity
        return identity
    }
}

extension Identity.Standalone.Configuration {
    public init(
        baseURL: URL,
        identity: Identity,
        jwt: Identity.Token.Client,
        cookies: Identity.Frontend.Configuration.Cookies? = nil,
        branding: Branding = .default,
        navigation: Navigation = .default,
        redirect: Redirect? = nil,
        rateLimiters: RateLimiters? = .default,
        currentUserName: (@Sendable () async throws -> String?)? = nil,
        canonicalHref: (@Sendable (Identity.View) -> URL?)? = nil,
        hreflang: ( @Sendable (Identity.View, Language) -> URL)? = nil
    ) {
        self = .init(
            baseURL: baseURL,
            identity: identity,
            jwt: jwt,
            cookies: cookies ?? .live(identity.router, domain: baseURL.host),
            branding: branding,
            navigation: navigation,
            redirect: redirect ?? .default(router: identity.router),
            rateLimiters: rateLimiters,
            currentUserName: currentUserName,
            canonicalHref: canonicalHref,
            hreflang: hreflang
        )
    }
}

