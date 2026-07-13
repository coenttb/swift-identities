import Dependencies
import Foundation

// MARK: - UUID Dependency Key
//
// The institute's `swift-dependencies` package (unlike PointFree's original
// swift-dependencies) does not vend a built-in UUID-generator dependency — there
// is no `\.uuid` key anywhere in that package. This is the local extension point,
// following the exact shape of `swift-dependencies`'s own `Clocks Dependency`
// target (`Dependency+Clock.swift`'s `ClockKey` + `__DependencyValues.clock`):
// a private `Dependency.Key` witness plus a `Dependency.Values` computed property.
//
// `Dependency.Key` (== `Witness.Key`) requires only `liveValue`; `previewValue`
// defaults to `liveValue` and `testValue` defaults to `previewValue`, so a single
// `liveValue` is sufficient here.
private enum UUIDGeneratorKey: Dependency.Key {
    static var liveValue: @Sendable () -> UUID {
        { UUID() }
    }
}

// MARK: - Dependency.Values Extension

extension Dependency.Values {
    /// A UUID generator for creating unique identifiers (e.g. JWT token IDs).
    ///
    /// ```swift
    /// @Dependency(\.uuid) var uuid
    /// let tokenId = uuid().uuidString
    /// ```
    public var uuid: @Sendable () -> UUID {
        get { self[UUIDGeneratorKey.self] }
        set { self[UUIDGeneratorKey.self] = newValue }
    }
}
