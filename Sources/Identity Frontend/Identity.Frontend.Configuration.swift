//
//  Identity.Frontend.Configuration.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Foundation
@preconcurrency import IdentitiesTypes
import URLRouting
import ServerFoundation
import HTML
import ServerFoundationVapor
import Language
import Identity_Shared
import ServerFoundationVapor

extension Identity.Frontend {
    /// Configuration required for Frontend operations.
    ///
    /// This protocol-like structure defines what configuration both Consumer
    /// and Standalone must provide when using Frontend functionality.
    public struct Configuration: Sendable {
        public var baseURL: URL
        public var identity: Identity
        public var jwt: Identity.Token.Client
        public var cookies: Identity.Frontend.Configuration.Cookies
        public var branding: Branding
        public var navigation: Navigation
        public var redirect: Redirect
        public var rateLimiters: RateLimiters?  // Optional for Standalone
        public var currentUserName: @Sendable () async throws -> String?
        public var canonicalHref: @Sendable (Identity.View) -> URL?
        public var hreflang: @Sendable (Identity.View, Language) -> URL
        
        package init(
            baseURL: URL,
            identity: Identity,
            jwt: Identity.Token.Client,
            cookies: Identity.Frontend.Configuration.Cookies,
            branding: Branding,
            navigation: Navigation = .default,
            redirect: Redirect,
            rateLimiters: RateLimiters?,
            currentUserName: (@Sendable () async throws -> String?)? = nil,
            canonicalHref: (@Sendable (Identity.View) -> URL?)? = nil,
            hreflang: ( @Sendable (Identity.View, Language) -> URL)? = nil
        ) {
            self.cookies = cookies
            self.identity = identity
            self.jwt = jwt
            self.baseURL = baseURL
            self.branding = branding
            self.navigation = navigation
            self.redirect = redirect
            self.rateLimiters = rateLimiters
            self.currentUserName = currentUserName ?? {
                @Dependency(\.request) var request
                guard
                    let request,
                    let accessToken = request.auth.get(Identity.Token.Access.self)
                else { return "User" }
                return accessToken.displayName
            }
            
            // Use provided closures or create defaults using the passed router
            self.canonicalHref = canonicalHref ?? { view in
                identity.router.url(for: .view(view))
            }
            
            self.hreflang = hreflang ?? { view, _ in
                identity.router.url(for: .view(view))
            }
        }
        
        /// Redirect configuration shared between Consumer and Standalone
        public struct Redirect: Sendable {
            public var loginSuccess: @Sendable (Identity.ID) async throws -> URL
            public var loginProtected: @Sendable () async throws -> URL
            public var createProtected: @Sendable () async throws -> URL
            public var createVerificationSuccess: @Sendable () async throws -> URL
            public var logoutSuccess: @Sendable () async throws -> URL
            
            public init(
                loginSuccess: @escaping @Sendable (Identity.ID) async throws -> URL,
                loginProtected: @escaping @Sendable () async throws -> URL,
                createProtected: @escaping @Sendable () async throws -> URL,
                createVerificationSuccess: @escaping @Sendable () async throws -> URL,
                logoutSuccess: @escaping @Sendable () async throws -> URL
            ) {
                self.loginSuccess = loginSuccess
                self.loginProtected = loginProtected
                self.createProtected = createProtected
                self.createVerificationSuccess = createVerificationSuccess
                self.logoutSuccess = logoutSuccess
            }
        }
        
        /// Branding configuration for visual identity
        public struct Branding: Sendable {
            public var logo: Identity.View.Logo
//            public var favicons: Favicons
            public var footer_links: [(TranslatedString, URL)]
            
            public init(
                logo: Identity.View.Logo,
//                favicons: Favicons = Branding.defaultFavicons,
                footer_links: [(TranslatedString, URL)] = []
            ) {
                self.logo = logo
//                self.favicons = favicons
                self.footer_links = footer_links
            }
            
//            public static let defaultFavicons: Favicons = .init(
//                icon: .init(lightMode: .init(string: "/")!, darkMode: .init(string: "/")!),
//                apple_touch_icon: "",
//                manifest: "",
//                maskIcon: ""
//            )
        }
        
        /// Navigation configuration
        public struct Navigation: Sendable {
            public var home: URL
            
            public init(
                home: URL = URL(string: "/")!
            ) {
                self.home = home
            }
            
            public static let `default`: Self = .init(home: URL(string: "/")!)
        }
    }
}




extension Identity.Frontend.Configuration: TestDependencyKey {
    public static var testValue: Identity.Frontend.Configuration {
        let baseURL = URL(string: "http://localhost:8080")!
        
        let router: any ParserPrinter<URLRequestData, Identity.Route> = Identity.Route.Router().baseURL(baseURL.absoluteString)
        
        return .init(
            baseURL: baseURL,
            identity: .testValue,
            jwt: .live(
                configuration: .init(
                    issuer: "identity-test",
                    audience: nil,
                    secretKey: "test-secret-key-min-32-bytes-long-for-testing",
                    accessTokenExpiry: 10, // 10 seconds for fast testing
                    refreshTokenExpiry: 60, // 1 minute
                    reauthorizationTokenExpiry: 5 // 5 seconds
                )
            ),
            cookies: .init(
                accessToken: .init(
                    expires: 60, // 1 minute for fast testing
                    maxAge: 60,
                    domain: nil,
                    path: "/",
                    isSecure: false,
                    isHTTPOnly: true,
                    sameSitePolicy: .none
                ),
                refreshToken: .init(
                    expires: 300, // 5 minutes
                    maxAge: 300,
                    domain: nil,
                    path: "/",
                    isSecure: false,
                    isHTTPOnly: true,
                    sameSitePolicy: .none
                ),
                reauthorizationToken: .init(
                    expires: 30, // 30 seconds
                    maxAge: 30,
                    domain: nil,
                    path: "/",
                    isSecure: false,
                    isHTTPOnly: true,
                    sameSitePolicy: .none
                )
            ),
            branding: .init(
                logo: .init(logo: "", href: baseURL)
            ),
            redirect: {
                let loginURL = router.url(for: .authenticate(.view(.credentials)))
                return .init(
                    loginSuccess: { _ in baseURL },
                    loginProtected: { loginURL },
                    createProtected: { loginURL },
                    createVerificationSuccess: { loginURL },
                    logoutSuccess: { baseURL }
                )
            }(),
            rateLimiters: .init(
                credentials: RateLimiter<String>(
                    windows: [
                        .seconds(10, maxAttempts: 5), // Very lenient for testing
                        .minutes(1, maxAttempts: 20)
                    ]
                )
            )
        )
    }
}

extension Identity.Frontend.Configuration.Redirect {
    public static func `default`(router: any ParserPrinter<URLRequestData, Identity.Route>) -> Self {
        let home = URL(string: "/")!
        let loginURL = router.url(for: .authenticate(.view(.credentials)))
        return .init(
            loginSuccess: { _ in home },
            loginProtected: { loginURL },
            createProtected: { loginURL },
            createVerificationSuccess: { loginURL },
            logoutSuccess: { home }
        )
    }
}

extension Identity.Frontend.Configuration.Branding {
    public static var `default`: Self {
        
        struct Test: HTML, Sendable {
            var body: some HTML {
                HTMLEmpty()
            }
        }
        
        return .init(
            logo: .init(logo: Test(), href: .init(string: "/")!)
        )
    }
}
