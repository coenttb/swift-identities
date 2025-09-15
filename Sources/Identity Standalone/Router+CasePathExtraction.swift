//
//  Router+CasePathExtraction.swift
//  swift-identities
//
//  Generic router extraction using CasePaths
//

import Foundation
import URLRouting
import CasePaths

// MARK: - Generic Case Path Extraction

extension URLRouting.Router where Input == URLRequestData {
    /// Extract a nested router using a case path
    ///
    /// This allows chaining through nested route enums:
    /// ```swift
    /// router.email.extract(\.api).extract(\.change)
    /// ```
    public func extract<Child>(
        _ casePath: CasePath<Output, Child>
    ) -> any URLRouting.Router<Child> {
        self.map(
            .convert(
                apply: { casePath.extract(from: $0) },
                unapply: { casePath.embed($0) }
            )
        )
    }

    /// Extract a nested router using a key path (when the case path is available as a computed property)
    ///
    /// This provides even cleaner syntax:
    /// ```swift
    /// router.email[\.api][\.change]
    /// ```
    public subscript<Child>(
        casePath: CasePath<Output, Child>
    ) -> any URLRouting.Router<Child> {
        extract(casePath)
    }
}

// MARK: - Parameter Pack-Based Nested Extraction

extension URLRouting.Router where Input == URLRequestData {
    /// Extract through multiple levels of nesting using parameter packs
    ///
    /// This allows unlimited levels of nesting in a single call:
    /// ```swift
    /// router.nested(\.email, \.api, \.change)
    /// router.nested(\.mfa, \.totp, \.api, \.enable)
    /// ```
    public func nested<each T>(
        _ paths: repeat CasePath<each T, each T>
    ) -> any URLRouting.Router<(repeat each T)> {
        var result: any URLRouting.Router = self

        for path in repeat each paths {
            result = result.extract(path)
        }

        return result as! any URLRouting.Router<(repeat each T)>
    }
}

// MARK: - Protocol-Based Approach (Optional)

/// Protocol for types that can provide router extraction paths
public protocol RouterExtractable {
    associatedtype Route
    static var routerPath: CasePath<Route, Self> { get }
}

// Then conform your types:
// extension Identity.Password.API: RouterExtractable {
//     static var routerPath: CasePath<Identity.Password.Route, Self> { \.api }
// }

// This would allow:
// router.password.extract(Identity.Password.API.routerPath)