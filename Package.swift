// swift-tools-version: 6.3.1

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

    // BLOCKED (institute-transfer wave): the following institute equivalents exist on disk but
    // their consuming targets cannot yet build against institute-only packages. See notes below.
    //
    // swift-html (institute) vends a single consolidated `HTML` module — the coenttb submodule
    // products HTMLEmail / HTMLMarkdown / HTMLWebsite / HTMLTheme / HTMLCSSPointFreeHTML DO NOT
    // exist in the institute package, and there is no institute `Language` /
    // `PointFreeHTMLTranslating` module. This blocks Identity Views/Frontend/Consumer/Standalone
    // and (via HTMLEmail) Identity Backend/Provider.
    //
    // static var html: Self { .product(name: "HTML", package: "swift-html") }
    // static var records: Self { .product(name: "Records", package: "swift-records") }
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

        // BLOCKED this wave — depend on missing institute HTML submodules / `Language` module.
        // Re-enable once swift-html vends HTMLEmail/HTMLWebsite/HTMLMarkdown/HTMLTheme and a
        // `Language` module lands in the institute ecosystem.
        // .library(name: .identityProvider, targets: [.identityProvider]),
        // .library(name: .identityConsumer, targets: [.identityConsumer]),
        // .library(name: .identityStandalone, targets: [.identityStandalone]),
        // .library(name: .identityViews, targets: [.identityViews]),
        // .library(name: .identityBackend, targets: [.identityBackend]),
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

        // BLOCKED this wave (institute equivalents exist on disk but only the blocked targets
        // consume them; declared here for the follow-up wave that re-enables those targets):
        // .package(url: "https://github.com/swift-foundations/swift-records.git", branch: "main"),
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

        // ================= BLOCKED (institute-transfer wave) =================
        // Every target below imports at least one module with no institute equivalent:
        //   - HTMLWebsite / HTMLMarkdown / HTMLTheme / HTMLCSSPointFreeHTML / HTMLEmail
        //     (institute swift-html vends only the consolidated `HTML` module)
        //   - `Language` and `PointFreeHTMLTranslating` (no institute module on disk)
        // Identity Backend/Provider additionally need HTMLEmail; Identity Backend/Standalone
        // need Records (institute swift-records still carries coenttb/pointfree edges upstream).
        // Re-enable target-by-target as the missing institute modules land.
        //
        // .target(
        //     name: .identityViews,
        //     dependencies: [
        //         .identityShared,
        //         .html,
        //         .htmlEmail,
        //         .htmlWebsite,
        //         .htmlMarkdown,
        //         .serverFoundation,
        //         .serverFoundationVapor
        //     ]
        // ),
        // .target(
        //     name: .identityBackend,
        //     dependencies: [
        //         .identityShared,
        //         .serverFoundation,
        //         .serverFoundationVapor,
        //         .records,
        //         .htmlEmail
        //     ]
        // ),
        // .target(
        //     name: .identityFrontend,
        //     dependencies: [
        //         .identitiesTypes,
        //         .identityShared,
        //         .identityViews,
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
        //         .serverFoundation,
        //         .serverFoundationVapor
        //     ]
        // ),
        // .target(
        //     name: .identityProvider,
        //     dependencies: [
        //         .identitiesTypes,
        //         .identityShared,
        //         .identityBackend,
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
