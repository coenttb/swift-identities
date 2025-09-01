// swift-tools-version:6.0

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
    static var boiler: Self { .product(name: "Boiler", package: "boiler") }
    static var coenttbWeb: Self { .product(name: "Coenttb Web", package: "coenttb-web") }
    static var coenttbEmail: Self { .product(name: "CoenttbEmail", package: "coenttb-html") }
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
    dependencies: [
        .package(url: "https://github.com/coenttb/boiler", from: "0.0.1"),
        .package(url: "https://github.com/coenttb/swift-records", from: "0.0.1"),
        .package(url: "https://github.com/coenttb/swift-identities-types", from: "0.0.1"),
        .package(url: "https://github.com/coenttb/swift-one-time-password", from: "0.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.2"),
        .package(url: "https://github.com/coenttb/coenttb-html", branch: "main"),
        .package(url: "https://github.com/coenttb/coenttb-web", branch: "main")
    ],
    targets: [
        .target(
            name: .identityShared,
            dependencies: [
                .identitiesTypes,
                .boiler,
                .totp
            ]
        ),
        .target(
            name: .identityViews,
            dependencies: [
                .identityShared,
                .coenttbEmail,
                .coenttbWeb
            ]
        ),
        .target(
            name: .identityBackend,
            dependencies: [
                .identityShared,
                .boiler,
                .records,
                .coenttbEmail
            ]
        ),
        .target(
            name: .identityFrontend,
            dependencies: [
                .identitiesTypes,
                .identityShared,
                .identityViews,
                .boiler
            ]
        ),
        .target(
            name: .identityConsumer,
            dependencies: [
                .identitiesTypes,
                .identityShared,
                .identityViews,
                .identityFrontend,
                .boiler
            ]
        ),
        .target(
            name: .identityProvider,
            dependencies: [
                .identitiesTypes,
                .identityShared,
                .identityBackend,
                .boiler
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
                .boiler
            ]
        ),
        .testTarget(
            name: .identityConsumer.tests,
            dependencies: [
                .identityConsumer,
                .identityProvider,
                .dependenciesTestSupport
            ]
        ),
        .testTarget(
            name: .identityProvider.tests,
            dependencies: [
                .identityProvider,
                .dependenciesTestSupport
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

extension String { var tests: Self { "\(self) Tests" } }
