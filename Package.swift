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
    static var identitiesTypes: Self { .product(name: "IdentitiesTypes", package: "swift-identities-types") }
    static var serverFoundation: Self { .product(name: "ServerFoundation", package: "swift-server-foundation") }
    static var serverFoundationVapor: Self {
        .product(
            name: "ServerFoundationVapor",
            package: "swift-server-foundation-vapor",
            condition: .when(traits: ["Vapor"])
        )
    }
    static var totp: Self { .product(name: "TOTP", package: "swift-time-based-one-time-password") }
    static var dependenciesTestSupport: Self { .product(name: "Dependencies Test Support", package: "swift-dependencies") }

    static var records: Self { .product(name: "Records", package: "swift-records") }
    // Identity Backend's MFA configuration files use `Tagged` directly (re-pointed off the
    // dissolving TypesFoundation umbrella, decomposition W2 2026-07-13):
    static var tagged: Self { .product(name: "Tagged Primitives", package: "swift-tagged-primitives") }
    // Needed by the still-red Frontend/Consumer/Standalone (declared ready for the HTML-tower arc;
    // Language EXISTS: swift-translating/Package.swift:45):
    static var language: Self { .product(name: "Language", package: "swift-translating") }

    // Still-red presentation deps (HTML-tower arc re-enables; institute swift-html vends the
    // consolidated `HTML` umbrella — the heritage HTMLEmail/HTMLWebsite/HTMLMarkdown/HTMLTheme/
    // HTMLCSSPointFreeHTML submodules do not exist as institute products):
    // static var html: Self { .product(name: "HTML", package: "swift-html") }
    // static var recordsTestSupport: Self { .product(name: "RecordsTestSupport", package: "swift-records") }
}

let package = Package(
    name: "swift-authentication",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        // ACTIVE (buildable against institute-only packages this wave):
        .library(name: .identityShared, targets: [.identityShared]),

        // Re-enabled by the identity-reuse arc (2026-07-14): server-side sign-up/login surface.
        .library(name: .identityBackend, targets: [.identityBackend]),
        .library(name: .identityProvider, targets: [.identityProvider]),

        // DELIBERATELY still red — presentation stack, owned by the HTML-tower arc (sequenced
        // after identity-reuse; see Workspace/handoffs/DECISIONS-pass2/identity-html.md §5-W5):
        // .library(name: .identityConsumer, targets: [.identityConsumer]),
        // .library(name: .identityStandalone, targets: [.identityStandalone]),
        // .library(name: .identityViews, targets: [.identityViews]),
        // .library(name: .identityFrontend, targets: [.identityFrontend])
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
        .package(url: "https://github.com/swift-foundations/swift-server-foundation.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-server-foundation-vapor.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-identities-types.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-time-based-one-time-password.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-dependencies.git", branch: "main"),

        .package(url: "https://github.com/swift-foundations/swift-records.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-translating.git", branch: "main"),

        // Still-red targets' deps (HTML-tower arc re-enables):
        // .package(url: "https://github.com/swift-foundations/swift-structured-queries-postgres.git", branch: "main"),
        // .package(url: "https://github.com/swift-foundations/swift-html.git", branch: "main"),
    ],
    targets: [
        // ================= ACTIVE =================
        .target(
            name: .identityShared,
            dependencies: [
                .identitiesTypes,
                .serverFoundation,
                .serverFoundationVapor,
                .totp
            ]
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
                .identityShared,
                .serverFoundation,
                .serverFoundationVapor,
                .records,
                .tagged
            ]
        ),
        .target(
            name: .identityProvider,
            dependencies: [
                .identitiesTypes,
                .identityShared,
                .identityBackend,
                .serverFoundation,
                .serverFoundationVapor
            ]
        ),

        // ================= DELIBERATELY RED (HTML-tower arc) =================
        // The presentation stack is written against the retired protocol-era HTML surface
        // (heritage submodules HTMLWebsite/HTMLMarkdown/HTMLTheme/HTMLCSSPointFreeHTML/
        // PointFreeHTMLTranslating). The HTML-tower arc ports it onto the institute doctrine
        // (`HTML.View`/`HTML.Document` + swift-webpage + the swift-html `Translating` trait);
        // see Workspace/handoffs/DECISIONS-pass2/identity-html.md §1/§5-W5.
        //
        // .target(
        //     name: .identityViews,
        //     dependencies: [
        //         .identityShared,
        //         .html,
        //         .serverFoundation,
        //         .serverFoundationVapor
        //     ]
        // ),
        // .target(
        //     name: .identityFrontend,
        //     dependencies: [
        //         .identitiesTypes,
        //         .identityShared,
        //         .identityViews,
        //         .language,
        //         .serverFoundation,
        //         .serverFoundationVapor
        //     ]
        // ),
        // .target(
        //     name: .identityConsumer,
        //     dependencies: [
        //         .identitiesTypes,
        //         .identityShared,
        //         .identityViews,
        //         .identityFrontend,
        //         .language,
        //         .serverFoundation,
        //         .serverFoundationVapor
        //     ]
        // ),
        // .target(
        //     name: .identityStandalone,
        //     dependencies: [
        //         .identitiesTypes,
        //         .identityShared,
        //         .identityBackend,
        //         .identityViews,
        //         .identityFrontend,
        //         .serverFoundation,
        //         .serverFoundationVapor
        //     ]
        // ),
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
