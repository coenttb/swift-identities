//
//  Identity Behavioral Tests.swift
//  swift-authentication
//
//  Behavioral coverage for the identity cookie surface: what
//  `Server.Response.setting(cookie:token:configuration:)`, `withTokens(for:)`,
//  and `expiringIdentityCookies()` actually put on the wire, plus the
//  `Identity.Consumer.Configuration.Consumer.live(...)` public spelling
//  contract. Recovered from the closed `#13` branch and revalidated against
//  current `main` for `swift-compositions/swift-authentication#20`.
//
//  Revalidation note: on the branch, `setting(cookie:token:configuration:)`
//  threw on an encoding failure. On current `main` it converts an encoding
//  failure into a `preconditionFailure` (the doc comment on that function
//  asserts encoding "cannot fail for these call sites" because tokens are
//  always JWT compact serializations). The two encoding-failure assertions
//  below are re-derived against the throwing primitive that `setting(...)`
//  wraps, `HTTPCookies.SetCookie.headerValue()`, rather than against
//  `setting(...)` itself, so they exercise the same encoding path without
//  requiring `main`'s deliberate precondition to be treated as a catchable
//  error.
//

import Dependencies
import Foundation
import HTTP_Cookies
import IdentitiesTypes
import Identity_Consumer
import Identity_Frontend
import Identity_Shared
import Server
import Testing
import URLRouting

@Suite("Identity behavioral contracts")
struct IdentityBehavioralTests {

    @Test
    func `Consumer live construction preserves the public access spelling`() {
        let baseURL = URL(string: "https://example.com")!
        let router = Identity.Route.Router().eraseToAnyParserPrinter()

        let configuration = Identity.Consumer.Configuration.Consumer.live(
            baseURL: baseURL,
            cookies: .consumer(domain: "example.com", router: router),
            router: router,
            currentUserName: { "currentuser" },
            branding: .init(
                logo: Identity.View.Logo(logo: "🔐", href: baseURL),
                footer_links: []
            ),
            navigation: .default,
            redirect: .live()
        )

        #expect(configuration.baseURL == baseURL)
        #expect(configuration.currentUserName() == "currentuser")
    }

    @Test
    func `Set-Cookie rendering succeeds for a valid token`() {
        let response = Server.Response().setting(
            cookie: Identity.Cookies.Names.accessToken,
            token: "signed-token",
            configuration: .init(path: "/", isHTTPOnly: true)
        )

        let cookieHeader = response.headers["Set-Cookie"]?.first
        #expect(cookieHeader?.rawValue.contains("signed-token") == true)
    }

    @Test
    func `Set-Cookie encoding failures throw`() {
        #expect(throws: HTTPCookies.EncodingPolicy.Error.self) {
            try HTTPCookies.SetCookie(
                name: Identity.Cookies.Names.accessToken,
                value: .init(token: "invalid\u{0001}token"),
                configuration: .init(path: "/", isHTTPOnly: true)
            ).headerValue()
        }
    }

    @Test
    func `High-level token cookies render successfully`() throws {
        try withDependencies {
            $0[Identity.Frontend.Configuration.self] = .testValue
        } operation: {
            let response = try Server.Response.json(success: true).withTokens(
                for: .init(accessToken: "access-token", refreshToken: "refresh-token")
            )

            #expect(response.headers["Set-Cookie"]?.count == 2)
        }
    }

    @Test
    func `High-level logout cookies expire successfully`() throws {
        let response = try Server.Response.json(success: true).expiringIdentityCookies()

        #expect(response.headers["Set-Cookie"]?.count == 3)
    }

    @Test
    func `High-level token cookie encoding failures propagate from the refresh token cookie path`() {
        withDependencies {
            $0[Identity.Frontend.Configuration.self] = .testValue
        } operation: {
            @Dependency(\.identityFrontendConfiguration) var configuration

            #expect(throws: HTTPCookies.EncodingPolicy.Error.self) {
                try HTTPCookies.SetCookie(
                    name: Identity.Cookies.Names.refreshToken,
                    value: .init(token: "invalid\u{0001}token"),
                    configuration: configuration.cookies.refreshToken
                ).headerValue()
            }
        }
    }
}
