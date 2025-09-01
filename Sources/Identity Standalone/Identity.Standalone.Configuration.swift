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
    /// it needs the full Frontend configuration including the client.
    public typealias Configuration = Identity.Frontend.Configuration
}

extension DependencyValues {
    public var identity: Identity.Frontend.Configuration {
        get { self[Identity.Frontend.Configuration.self] }
        set { self[Identity.Frontend.Configuration.self] = newValue }
    }
}

extension Identity.Standalone.Configuration {
    public init(
        baseURL: URL,
        router: AnyParserPrinter<URLRequestData, Identity.Route>,
        client: Identity.Client,
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
            router: router,
            client: client,
            jwt: jwt,
            cookies: cookies ?? .live(router, domain: baseURL.host),
            branding: branding,
            navigation: navigation,
            redirect: redirect ?? .default(router: router),
            rateLimiters: rateLimiters,
            currentUserName: currentUserName,
            canonicalHref: canonicalHref,
            hreflang: hreflang
        )
    }
}

