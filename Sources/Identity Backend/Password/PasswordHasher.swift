//
//  PasswordHasher.swift
//  swift-identities
//
//  Created to decouple password hashing from Vapor framework
//

import Dependencies
import DependenciesMacros
import Foundation

/// Protocol for password hashing operations
///
/// This abstraction allows the identity backend to work with different
/// password hashing implementations without coupling to specific frameworks.
@DependencyClient
public struct PasswordHasher: Sendable {
  /// Hash a plaintext password
  ///
  /// - Parameters:
  ///   - password: The plaintext password to hash
  ///   - cost: The cost factor for the hash (higher = more secure but slower)
  /// - Returns: The hashed password string
  /// - Throws: If hashing fails
  public var hash: @Sendable (_ password: String, _ cost: Int) async throws -> String

  /// Verify a plaintext password against a hash
  ///
  /// - Parameters:
  ///   - password: The plaintext password to verify
  ///   - hash: The hash to verify against
  /// - Returns: True if the password matches the hash
  /// - Throws: If verification encounters an error
  public var verify: @Sendable (_ password: String, _ hash: String) async throws -> Bool
}

extension PasswordHasher: TestDependencyKey {
  public static let testValue = Self(
    hash: { password, cost in
      // Test implementation returns predictable hash
      return "test_hash_\(password)_cost\(cost)"
    },
    verify: { password, hash in
      // Test implementation uses simple string matching
      return hash.hasPrefix("test_hash_\(password)_")
    }
  )

  /// Preview implementation for SwiftUI previews
  public static let previewValue = testValue
}

// Fallback implementation when Vapor is not available
#if !canImport(Vapor)
extension PasswordHasher: DependencyKey {
  public static let liveValue: PasswordHasher = Self(
    hash: { password, cost in
      // When Vapor is not available, you must provide your own implementation
      // This could be Argon2, pure Swift bcrypt, or another hashing algorithm
      fatalError(
        """
        PasswordHasher.liveValue not implemented without Vapor trait.
        Either:
        1. Enable the Vapor trait in Package.swift, or
        2. Provide a custom PasswordHasher implementation via withDependencies
        """
      )
    },
    verify: { password, hash in
      fatalError(
        """
        PasswordHasher.liveValue not implemented without Vapor trait.
        Either:
        1. Enable the Vapor trait in Package.swift, or
        2. Provide a custom PasswordHasher implementation via withDependencies
        """
      )
    }
  )
}
#endif

extension DependencyValues {
  public var passwordHasher: PasswordHasher {
    get { self[PasswordHasher.self] }
    set { self[PasswordHasher.self] = newValue }
  }
}
