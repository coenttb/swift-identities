// swift-tools-version:6.1

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
    static var html: Self { .product(name: "HTML", package: "swift-html") }
    static var htmlEmail: Self { .product(name: "HTMLEmail", package: "swift-html") }
    static var htmlMarkdown: Self { .product(name: "HTMLMarkdown", package: "swift-html") }
    static var htmlWebsite: Self { .product(name: "HTMLWebsite", package: "swift-html") }
    static var records: Self { .product(name: "Records", package: "swift-records") }
    static var totp: Self { .product(name: "TOTP", package: "swift-one-time-password") }
    static var dependenciesTestSupport: Self { .product(name: "DependenciesTestSupport", package: "swift-dependencies") }
}

let package = Package(
    name: "swift-identities",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: .identityProvider, targets: [.identityProvider]),
        .library(name: .identityConsumer, targets: [.identityConsumer]),
        .library(name: .identityStandalone, targets: [.identityStandalone]),
        .library(name: .identityShared, targets: [.identityShared]),
        .library(name: .identityViews, targets: [.identityViews]),
        .library(name: .identityBackend, targets: [.identityBackend]),
        .library(name: .identityFrontend, targets: [.identityFrontend])
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
        .package(url: "https://github.com/coenttb/swift-server-foundation", from: "0.0.1"),
        .package(url: "https://github.com/coenttb/swift-server-foundation-vapor", from: "0.0.1"),
        .package(url: "https://github.com/coenttb/swift-records", from: "0.1.0"),
        .package(
            url: "https://github.com/coenttb/swift-structured-queries-postgres",
            from: "0.0.1",
            traits: ["StructuredQueriesPostgresTagged"]
        ),
        .package(url: "https://github.com/coenttb/swift-identities-types", from: "0.0.1"),
        .package(url: "https://github.com/coenttb/swift-one-time-password", from: "0.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.2"),
        .package(url: "https://github.com/coenttb/swift-html", from: "0.7.0"),
    ],
    targets: [
        .target(
            name: .identityShared,
            dependencies: [
                .identitiesTypes,
                .serverFoundation,
                .serverFoundationVapor,
                .totp
            ]
        ),
        .target(
            name: .identityViews,
            dependencies: [
                .identityShared,
                .html,
                .htmlEmail,
                .htmlWebsite,
                .htmlMarkdown,
                .serverFoundation,
                .serverFoundationVapor
            ]
        ),
        .target(
            name: .identityBackend,
            dependencies: [
                .identityShared,
                .serverFoundation,
                .serverFoundationVapor,
                .records,
                .htmlEmail
            ]
        ),
        .target(
            name: .identityFrontend,
            dependencies: [
                .identitiesTypes,
                .identityShared,
                .identityViews,
                .serverFoundation,
                .serverFoundationVapor
            ]
        ),
        .target(
            name: .identityConsumer,
            dependencies: [
                .identitiesTypes,
                .identityShared,
                .identityViews,
                .identityFrontend,
                .serverFoundation,
                .serverFoundationVapor
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
        .target(
            name: .identityStandalone,
            dependencies: [
                .identitiesTypes,
                .identityShared,
                .identityBackend,
                .identityViews,
                .identityFrontend,
                .serverFoundation,
                .serverFoundationVapor
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
        .testTarget(
            name: .identityViews.tests,
            dependencies: [
                .identityViews,
                .identityShared,
                .identitiesTypes,
                .dependenciesTestSupport
            ]
        ),
        .testTarget(
            name: .identityBackend.tests,
            dependencies: [
                .identityBackend,
                .identitiesTypes,
                .dependenciesTestSupport,
                .product(name: "RecordsTestSupport", package: "swift-records")
            ]
        ),
        .testTarget(
            name: .identityFrontend.tests,
            dependencies: [
                .identityFrontend,
                .identityShared,
                .identitiesTypes,
                .dependenciesTestSupport
            ]
        ),
        .testTarget(
            name: .identityConsumer.tests,
            dependencies: [
                .identityConsumer,
                .identityShared,
                .identityFrontend,
                .identitiesTypes,
                .dependenciesTestSupport
            ]
        ),
        .testTarget(
            name: .identityProvider.tests,
            dependencies: [
                .identityProvider,
                .identityShared,
                .identityBackend,
                .identitiesTypes,
                .dependenciesTestSupport,
                .product(name: "RecordsTestSupport", package: "swift-records")
            ]
        ),
        .testTarget(
            name: .identityStandalone.tests,
            dependencies: [
                .identityStandalone,
                .identityShared,
                .identityBackend,
                .identityFrontend,
                .identitiesTypes,
                .dependenciesTestSupport,
                .product(name: "RecordsTestSupport", package: "swift-records")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

extension String { var tests: Self { "\(self) Tests" } }
