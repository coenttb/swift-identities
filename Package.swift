// swift-tools-version: 6.3.3

import Foundation
import PackageDescription

extension String {
    static let identityProvider: Self = "Identity Provider"
    static let identityConsumer: Self = "Identity Consumer"
    static let identityStandalone: Self = "Identity Standalone"
    static let identityShared: Self = "Identity Shared"
    static let identityViews: Self = "Identity Views"
    static let identityBackend: Self = "Identity Backend"
    static let identityFrontend: Self = "Identity Frontend"
}

extension Target.Dependency {
    static var identityProvider: Self { .target(name: .identityProvider) }
    static var identityConsumer: Self { .target(name: .identityConsumer) }
    static var identityStandalone: Self { .target(name: .identityStandalone) }
    static var identityShared: Self { .target(name: .identityShared) }
    static var identityViews: Self { .target(name: .identityViews) }
    static var identityBackend: Self { .target(name: .identityBackend) }
    static var identityFrontend: Self { .target(name: .identityFrontend) }
}

extension Target.Dependency {
    static var dependencies: Self { .product(name: "Dependencies", package: "swift-dependencies") }
    static var identitiesTypes: Self { .product(name: "IdentitiesTypes", package: "swift-identities-types") }
    static var loggerDependencies: Self {
        .product(name: "Logger Dependencies", package: "swift-logger-dependencies")
    }
    static var logging: Self { .product(name: "Logging", package: "swift-log") }
    static var passwordValidation: Self { .product(name: "PasswordValidation", package: "swift-password") }
    static var server: Self { .product(name: "Server", package: "swift-server") }
    static var serverHTML: Self { .product(name: "Server HTML", package: "swift-server") }
    static var environment: Self { .product(name: "Environment Dependencies", package: "swift-environment-dependencies") }
    static var serverVapor: Self { .product(name: "Server Vapor", package: "swift-server-vapor") }
    static var vapor: Self { .product(name: "Vapor", package: "vapor") }
    static var httpCookies: Self { .product(name: "HTTP Cookies", package: "swift-http-cookies") }
    static var httpRedirect: Self { .product(name: "HTTP Redirect", package: "swift-http-redirect") }
    static var httpHost: Self { .product(name: "HTTP Host", package: "swift-http-host") }
    static var httpSession: Self { .product(name: "HTTP Session", package: "swift-http-session") }
    static var throttling: Self { .product(name: "Throttling", package: "swift-throttling") }
    static var uri: Self { .product(name: "URI", package: "swift-uri") }
    static var urlRequestHandler: Self { .product(name: "URLRequestHandler", package: "swift-urlrequest-handler") }
    static var totp: Self { .product(name: "TOTP", package: "swift-time-based-one-time-password") }
    static var dependenciesTestSupport: Self { .product(name: "Dependencies Test Support", package: "swift-dependencies") }

    static var dateExtensions: Self { .product(name: "DateExtensions", package: "swift-foundation-extensions") }
    static var records: Self { .product(name: "Records", package: "swift-records") }
    // Identity Backend's MFA configuration files use `Tagged` directly (re-pointed off the
    // dissolving TypesFoundation umbrella, decomposition W2 2026-07-13):
    static var tagged: Self { .product(name: "Tagged Primitives", package: "swift-tagged-primitives") }
    // Needed by the still-red Frontend/Consumer/Standalone (declared ready for the HTML-tower arc;
    // Language EXISTS: swift-translating/Package.swift:45):
    static var language: Self { .product(name: "Language", package: "swift-translating") }

    // Presentation deps (HTML-tower arc, W-V wave 2026-07-14). The institute swift-html vends the
    // consolidated `HTML` umbrella; the heritage HTMLEmail/HTMLWebsite/HTMLMarkdown/HTMLTheme/
    // HTMLCSSPointFreeHTML submodules do not exist as institute products — the component layer
    // (PageModule/Link/Input/Button/Header/Paragraph) now lives in swift-webpage, and the retired
    // translations-era `String.xxx` constants live in swift-webpage behind `#if TRANSLATING`.
    static var html: Self { .product(name: "HTML", package: "swift-html") }
    static var webpage: Self { .product(name: "Webpage", package: "swift-webpage") }
    static var translating: Self { .product(name: "Translating", package: "swift-translating") }
    // static var recordsTestSupport: Self { .product(name: "RecordsTestSupport", package: "swift-records") }
}

let package = Package(
    name: "swift-authentication",
    platforms: [
        .macOS("27"),
        .iOS("27")
    ],
    products: [
        // ACTIVE (buildable against institute-only packages this wave):
        .library(name: .identityShared, targets: [.identityShared]),

        // Re-enabled by the identity-reuse arc (2026-07-14): server-side sign-up/login surface.
        .library(name: .identityBackend, targets: [.identityBackend]),
        .library(name: .identityProvider, targets: [.identityProvider]),

        // Re-enabled by the HTML-tower arc, W-V wave (2026-07-14): the view layer, ported onto
        // the institute HTML doctrine (HTML.View / HTML.Document.Protocol + swift-webpage +
        // the swift-html `Translating` trait).
        .library(name: .identityViews, targets: [.identityViews]),

        // HTML-tower arc, W2 wave (2026-07-14): frontend + consumer, ported onto the institute
        // doctrine alongside Views. Both gate green.
        .library(name: .identityConsumer, targets: [.identityConsumer]),
        .library(name: .identityFrontend, targets: [.identityFrontend])

        // STILL RED — `Identity Standalone`. Its sources carry the W2 port (dep-key, HTML surface,
        // @Cases), but the target does NOT compile and is held for a ruling.
        //
        // Residue: 85 unique source sites across 10 files. (611 anchored compiler diagnostics — a
        // FLOOR on symptoms, never a cost: errors mask errors, so the class mix will shift as the
        // dominant class clears.) Largest single file: Router+SubRoutes.swift — 252 diagnostics
        // over just 12 call sites.
        //
        // Root cause (reasoned from source; NOT gate-verified): those 12 sites downcast a router,
        // `Router<Identity.Route>` -> `Router<Identity.Authentication.Route>`, via
        // `.convert(apply: \.caseName, unapply: Identity.Route.caseName)`. The institute `.convert`
        // is backed by `Parser.Conversion.Case`, whose FORWARD direction is the total `embed` and
        // whose REVERSE is the partial `extract` — a downcast needs exactly the opposite. `apply:`
        // therefore demands a NON-OPTIONAL `(Identity.Route) -> Identity.Authentication.Route`,
        // which no case key path can supply: payload extraction is partial by nature. This is a
        // conversion-FAILABILITY-DIRECTION gap, not a missing-key-path gap — vending case key
        // paths from `@Cases` would NOT fix it. See drift-map/WAVE2-DRIFT.md §Q-2.
        // .library(name: .identityStandalone, targets: [.identityStandalone]),
    ],
    traits: [
        .trait(
            name: "Vapor",
            description: "Enable Vapor framework integration for server-side password hashing (Bcrypt) and HTTP utilities."
        ),
        .default(
            enabledTraits: [
                "Vapor"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-foundations/swift-server.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-environment-dependencies.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-server-vapor.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-password.git", branch: "main"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.102.1"),
        .package(url: "https://github.com/swift-foundations/swift-http-cookies.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-http-redirect.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-http-host.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-http-session.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-throttling.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-uri.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-urlrequest-handler.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-identities-types.git", branch: "main"),
        // Batch-0 parity corpus: test-support product only (Authentication Router Parity Tests).
        .package(url: "https://github.com/swift-foundations/swift-url-routing.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-time-based-one-time-password.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-dependencies.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-logger-dependencies.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),

        .package(url: "https://github.com/swift-standards/swift-postgresql-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-foundation-extensions.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-records.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-translating.git", branch: "main"),

        // Presentation stack (HTML-tower arc, W-V wave). The `Translating` trait must be requested
        // on BOTH deps: swift-webpage passes NO traits to its own swift-html dependency, so the
        // ROOT package is what unifies the trait across the graph. With it ON, swift-webpage's
        // `TranslatedString.swift` (`#if TRANSLATING`) vends the ~115 `String.xxx` translation
        // constants these views read, and swift-html's `TranslatedString+HTML.swift` supplies the
        // `Translated<String>: HTML.View` conformance that lets them appear in builder blocks.
        .package(url: "https://github.com/swift-foundations/swift-html.git", branch: "main", traits: ["Translating"]),
        .package(url: "https://github.com/swift-foundations/swift-webpage.git", branch: "main", traits: ["Translating"]),

        // Still-red targets' deps (later HTML-tower waves re-enable):
        // .package(url: "https://github.com/swift-foundations/swift-structured-queries-postgres.git", branch: "main"),
    ],
    targets: [
        // ================= ACTIVE =================
        .target(
            name: .identityShared,
            dependencies: [
                .dependencies,
                .identitiesTypes,
                .loggerDependencies,
                .logging,
                .server,
                .environment,
                .serverVapor,
                .vapor,
                .httpCookies,
                .httpRedirect,
                .httpHost,
                .httpSession,
                .throttling,
                .uri,
                .totp
            ]
        ),
        // Batch-0 wire-shape parity corpus (url-routing-stack migration).
        .testTarget(
            name: "Authentication Router Parity Tests",
            dependencies: [
                .identityShared,
                .identityProvider,
                .identityConsumer,
                .identityFrontend,
                .identitiesTypes,
                .dependencies,
                .server,
                .serverVapor,
                .httpCookies,
                .product(name: "URL Routing Test Support", package: "swift-url-routing")
            ],
            path: "Tests/Authentication Router Parity Tests",
            exclude: ["__Corpus__"]
        ),
        .testTarget(
            name: .identityShared.tests,
            dependencies: [
                .identityShared,
                .identitiesTypes,
                .dependenciesTestSupport
            ]
        ),

        // ================= ACTIVE (identity-reuse arc, 2026-07-14) =================
        .target(
            name: .identityBackend,
            dependencies: [
                .dateExtensions,
                .dependencies,
                .identityShared,
                .loggerDependencies,
                .logging,
                .passwordValidation,
                .server,
                .environment,
                .serverVapor,
                .vapor,
                .httpCookies,
                .httpRedirect,
                .httpHost,
                .httpSession,
                .throttling,
                .uri,
                .records,
                .product(name: "PostgreSQL Standard Macros", package: "swift-postgresql-standard"),
                .tagged
            ]
        ),
        .target(
            name: .identityProvider,
            dependencies: [
                .dependencies,
                .identitiesTypes,
                .identityShared,
                .identityBackend,
                .loggerDependencies,
                .logging,
                .server,
                .environment,
                .serverVapor,
                .vapor,
                .httpCookies,
                .httpRedirect,
                .httpHost,
                .httpSession,
                .throttling,
                .uri
            ]
        ),

        // ================= ACTIVE (HTML-tower arc, W-V wave 2026-07-14) =================
        // Ported off the retired protocol-era HTML surface (heritage submodules HTMLWebsite/
        // HTMLMarkdown/HTMLTheme/HTMLCSSPointFreeHTML/PointFreeHTMLTranslating) onto the institute
        // doctrine (`HTML.View` / `HTML.Document.Protocol` + swift-webpage + the `Translating`
        // trait); see Workspace/handoffs/DECISIONS-pass2/identity-html.md §1/§5-W5.
        .target(
            name: .identityViews,
            dependencies: [
                .identityShared,
                .html,
                .webpage,
                .translating,
                .language,
                .server,
                .environment,
                .serverVapor,
                .vapor,
                .httpCookies,
                .httpRedirect,
                .httpHost,
                .httpSession,
                .throttling,
                .uri
            ]
        ),

        // ================= ACTIVE (HTML-tower arc, W2 wave 2026-07-14) =================
        .target(
            name: .identityFrontend,
            dependencies: [
                .identitiesTypes,
                .identityShared,
                .identityViews,
                .language,
                .server,
                .serverHTML,
                .environment,
                .serverVapor,
                .vapor,
                .httpCookies,
                .httpRedirect,
                .httpHost,
                .httpSession,
                .throttling,
                .uri
            ]
        ),
        .target(
            name: .identityConsumer,
            dependencies: [
                .urlRequestHandler,
                .dependencies,
                .identitiesTypes,
                .identityShared,
                .identityViews,
                .identityFrontend,
                .language,
                .loggerDependencies,
                .logging,
                .server,
                .environment,
                .serverVapor,
                .vapor,
                .httpCookies,
                .httpRedirect,
                .httpHost,
                .httpSession,
                .throttling,
                .uri
            ]
        ),
        // ================= STILL RED (HTML-tower W2 — held, see WAVE2-DRIFT.md) =================
        // `Identity Standalone` does NOT compile. Its sources DO carry the W2 port (dep-key
        // conformances, HTML surface tokens, `@Cases`); the residue is 85 unique sites over 10
        // files, whose dominant class is the 12 router-downcast `.convert` calls in
        // `Router+SubRoutes.swift`. That class is a conversion-failability-direction gap in
        // `.convert` (see the product block above), NOT a missing case-key-path — so it is not a
        // mechanical fix and is held for a ruling.
        // ⚠️ The sources below are therefore UNVERIFIED — they have never been type-checked.
        // .target(
        //     name: .identityStandalone,
        //     dependencies: [
        //         .identitiesTypes,
        //         .identityShared,
        //         .identityBackend,
        //         .identityViews,
        //         .identityFrontend,
        //         .server,
        //         .environment
        //     ]
        // ),

        // ================= STILL OFF (test targets — until the port is green) =================
        // .testTarget(
        //     name: .identityViews.tests,
        //     dependencies: [.identityViews, .identityShared, .identitiesTypes, .dependenciesTestSupport]
        // ),
        // .testTarget(
        //     name: .identityBackend.tests,
        //     dependencies: [.identityBackend, .identitiesTypes, .dependenciesTestSupport, .recordsTestSupport]
        // ),
        // .testTarget(
        //     name: .identityFrontend.tests,
        //     dependencies: [.identityFrontend, .identityShared, .identitiesTypes, .dependenciesTestSupport]
        // ),
        // .testTarget(
        //     name: .identityConsumer.tests,
        //     dependencies: [.identityConsumer, .identityShared, .identityFrontend, .identitiesTypes, .dependenciesTestSupport]
        // ),
        // .testTarget(
        //     name: .identityProvider.tests,
        //     dependencies: [.identityProvider, .identityShared, .identityBackend, .identitiesTypes, .dependenciesTestSupport, .recordsTestSupport]
        // ),
        // .testTarget(
        //     name: .identityStandalone.tests,
        //     dependencies: [.identityStandalone, .identityShared, .identityBackend, .identityFrontend, .identitiesTypes, .dependenciesTestSupport, .recordsTestSupport]
        // )
    ],
    swiftLanguageModes: [.v6]
)

extension String { var tests: Self { "\(self) Tests" } }
