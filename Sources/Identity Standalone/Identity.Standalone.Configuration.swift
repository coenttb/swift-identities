//
//  Identity.Standalone.Configuration.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Dependencies
import IdentitiesTypes
import Identity_Backend
@preconcurrency import Identity_Frontend
import Identity_Shared
import Language
import ServerFoundation
import URLRouting

extension Identity.Standalone {
  /// Standalone configuration that includes both Frontend and Backend configurations
  /// This is the central configuration point that orchestrates both
  public struct Configuration: Sendable {
    /// Frontend configuration
    public var baseURL: URL
    public var router: any URLRouting.Router<Identity.Route>
    public var jwt: Identity.Token.Client
    public var cookies: Identity.Standalone.Configuration.Cookies
    public var branding: Identity.Standalone.Configuration.Branding
    public var navigation: Identity.Standalone.Configuration.Navigation
    public var redirect: Identity.Standalone.Configuration.Redirect
    public var rateLimiters: RateLimiters?
    public var currentUserName: @Sendable () async throws -> String?
    public var canonicalHref: @Sendable (Identity.View) -> URL?
    public var hreflang: @Sendable (Identity.View, Language) -> URL

    public typealias Cookies = Identity.Frontend.Configuration.Cookies
    public typealias Branding = Identity.Frontend.Configuration.Branding
    public typealias Navigation = Identity.Frontend.Configuration.Navigation
    public typealias Redirect = Identity.Frontend.Configuration.Redirect
    public typealias Email = Identity.Backend.Configuration.Email
    public typealias TokenEnrichment = Identity.Backend.Configuration.TokenEnrichment

    /// Backend configuration
    public var email: Identity.Backend.Configuration.Email
    public var tokenEnrichment: Identity.Backend.Configuration.TokenEnrichment?
    public var mfa: Identity.MFA.Configuration?
    public var oauth: Identity.OAuth.Configuration?

    package init(
      baseURL: URL,
      router: any URLRouting.Router<Identity.Route>,
      jwt: Identity.Token.Client,
      cookies: Identity.Standalone.Configuration.Cookies,
      branding: Identity.Standalone.Configuration.Branding,
      navigation: Identity.Standalone.Configuration.Navigation,
      redirect: Identity.Standalone.Configuration.Redirect,
      rateLimiters: RateLimiters?,
      currentUserName: (@Sendable () async throws -> String?)? = nil,
      canonicalHref: (@Sendable (Identity.View) -> URL?)? = nil,
      hreflang: (@Sendable (Identity.View, Language) -> URL)? = nil,
      email: Identity.Backend.Configuration.Email,
      tokenEnrichment: TokenEnrichment? = nil,
      mfa: Identity.MFA.Configuration? = nil,
      oauth: Identity.OAuth.Configuration? = nil
    ) {
      self.baseURL = baseURL
      self.router = router
      self.jwt = jwt
      self.cookies = cookies
      self.branding = branding
      self.navigation = navigation
      self.redirect = redirect
      self.rateLimiters = rateLimiters
      self.currentUserName =
        currentUserName ?? {
          @Dependency(\.request) var request
          guard
            let request,
            let accessToken = request.auth.get(Identity.Token.Access.self)
          else { return "User" }
          return accessToken.displayName
        }
      self.canonicalHref =
        canonicalHref ?? { view in
          router.url(for: .view(view))
        }
      self.hreflang =
        hreflang ?? { view, _ in
          router.url(for: .view(view))
        }
      self.email = email
      self.tokenEnrichment = tokenEnrichment
      self.mfa = mfa
      self.oauth = oauth
    }
  }
}

extension Identity.Standalone.Configuration: TestDependencyKey {
  public static var testValue: Self {
    fatalError(
      "Identity.Standalone.Configuration.testValue not implemented - use withDependencies to provide test configuration"
    )
  }
}

extension Identity.Standalone.Configuration {
  /// Convenience initializer with defaults
  public init(
    baseURL: URL,
    router: any URLRouting.Router<Identity.Route>,
    jwt: Identity.Token.Client,
    cookies: Identity.Frontend.Configuration.Cookies? = nil,
    branding: Identity.Frontend.Configuration.Branding = .default,
    navigation: Identity.Frontend.Configuration.Navigation = .default,
    redirect: Identity.Frontend.Configuration.Redirect? = nil,
    rateLimiters: RateLimiters? = .default,
    currentUserName: (@Sendable () async throws -> String?)? = nil,
    canonicalHref: (@Sendable (Identity.View) -> URL?)? = nil,
    hreflang: (@Sendable (Identity.View, Language) -> URL)? = nil,
    email: Identity.Backend.Configuration.Email = .noop,
    tokenEnrichment: Identity.Backend.Configuration.TokenEnrichment? = nil,
    mfa: Identity.MFA.Configuration? = nil,
    oauth: Identity.OAuth.Configuration? = nil
  ) {
    self = .init(
      baseURL: baseURL,
      router: router,
      jwt: jwt,
      cookies: cookies ?? .live(router, domain: baseURL.host),
      branding: branding,
      navigation: navigation,
      redirect: redirect ?? .default(router: router),
      rateLimiters: rateLimiters,
      currentUserName: currentUserName,
      canonicalHref: canonicalHref,
      hreflang: hreflang,
      email: email,
      tokenEnrichment: tokenEnrichment,
      mfa: mfa,
      oauth: oauth
    )
  }
}
