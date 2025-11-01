//
//  PasswordHasher+Vapor.swift
//  swift-identities
//
//  Vapor implementation of PasswordHasher using Bcrypt
//

import Dependencies
import Vapor

extension PasswordHasher {
  /// Live implementation using Vapor's Bcrypt on a thread pool
  ///
  /// This implementation uses Vapor's Application thread pool to run bcrypt
  /// operations on a background thread, preventing blocking of async contexts.
  public static var vapor: Self {
    Self(
      hash: { password, cost in
        @Dependency(\.application) var application

        return try await application.threadPool.runIfActive {
          try Bcrypt.hash(password, cost: cost)
        }
      },
      verify: { password, hash in
        @Dependency(\.application) var application

        return try await application.threadPool.runIfActive {
          try Bcrypt.verify(password, created: hash)
        }
      }
    )
  }
}

extension PasswordHasher: DependencyKey {
  public static let liveValue: PasswordHasher = .vapor
}
