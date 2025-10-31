//
//  Identity.API.protect+helpers.swift
//  swift-identities
//
//  Helper functions for authentication enforcement
//

import Dependencies
import ServerFoundationVapor

extension Identity.API {
  /// Requires authentication for the current request
  ///
  /// This helper consolidates the repeated pattern of:
  /// - Getting the request dependency
  /// - Checking it's available
  /// - Requiring authentication
  ///
  /// - Parameter type: The authenticatable type to require
  /// - Throws: `Abort.requestUnavailable` if no request context
  /// - Throws: `Abort.unauthorized` if not authenticated
  package static func requireAuthentication<A: Vapor.Authenticatable>(
    _ type: A.Type
  ) throws {
    @Dependency(\.request) var request
    guard let request else { throw Abort.requestUnavailable }
    try request.auth.require(type)
  }
}
