//
//  Identity.Backend.Error.swift
//  swift-identities
//
//  Domain error types for Identity Backend (framework-agnostic)
//

import Foundation
import IdentitiesTypes

extension Identity.Backend {
  /// Framework-agnostic domain errors for Identity Backend
  /// These errors can be transformed to HTTP responses at the application edge
  public enum Error: Swift.Error, Equatable, Sendable {
    // MARK: - Authentication Errors

    /// Invalid username or password
    case invalidCredentials

    /// Email address has not been verified
    case emailNotVerified

    /// User is not authenticated
    case notAuthenticated

    /// Invalid or expired token
    case invalidToken(type: TokenType)

    /// Invalid reauthorization token
    case invalidReauthorizationToken

    /// Session has been invalidated
    case sessionInvalidated

    /// Identity details have changed, session is no longer valid
    case identityDetailsChanged

    /// Token has been revoked
    case tokenRevoked

    /// Invalid API key
    case invalidAPIKey

    /// API key has expired
    case apiKeyExpired

    // MARK: - Not Found Errors

    /// Identity not found
    case identityNotFound(identifier: IdentityIdentifier)

    // MARK: - Validation Errors

    /// Email address already in use
    case emailAlreadyInUse

    /// Email addresses don't match
    case emailMismatch

    /// Invalid input
    case invalidInput(String)

    // MARK: - State Errors

    /// User is already pending deletion
    case alreadyPendingDeletion

    /// User is not pending deletion
    case notPendingDeletion

    /// Deletion grace period has not expired
    case deletionGracePeriodNotExpired

    // MARK: - Internal Errors

    /// Failed to create identity
    case failedToCreateIdentity

    /// Failed to create verification token
    case failedToCreateToken(type: TokenType)

    /// Request context is unavailable
    case requestUnavailable

    /// Configuration error
    case configurationError(String)

    /// Unexpected error occurred
    case unexpected(String)

    // MARK: - Supporting Types

    public enum TokenType: String, Sendable, Equatable {
      case emailVerification
      case passwordReset
      case emailChange
      case access
      case refresh
      case reauthorization
    }

    public enum IdentityIdentifier: Sendable, Equatable {
      case id(Identity.ID)
      case email(String)
      case auth  // From authentication context
    }
  }
}

// MARK: - Error Descriptions

extension Identity.Backend.Error: CustomStringConvertible {
  public var description: String {
    switch self {
    case .invalidCredentials:
      return "Invalid credentials"
    case .emailNotVerified:
      return "Email not verified"
    case .notAuthenticated:
      return "Not authenticated"
    case .invalidToken(let type):
      return "Invalid or expired \(type.rawValue) token"
    case .invalidReauthorizationToken:
      return "Invalid reauthorization token"
    case .sessionInvalidated:
      return "Session has been invalidated"
    case .identityDetailsChanged:
      return "Identity details have changed"
    case .tokenRevoked:
      return "Token has been revoked"
    case .invalidAPIKey:
      return "Invalid API key"
    case .apiKeyExpired:
      return "API key has expired"
    case .identityNotFound(let identifier):
      switch identifier {
      case .id(let id):
        return "Identity not found: \(id)"
      case .email(let email):
        return "Identity not found: \(email)"
      case .auth:
        return "Identity not found from authentication context"
      }
    case .emailAlreadyInUse:
      return "Email already in use"
    case .emailMismatch:
      return "Email mismatch"
    case .invalidInput(let message):
      return "Invalid input: \(message)"
    case .alreadyPendingDeletion:
      return "Already pending deletion"
    case .notPendingDeletion:
      return "Not pending deletion"
    case .deletionGracePeriodNotExpired:
      return "Deletion grace period has not expired"
    case .failedToCreateIdentity:
      return "Failed to create identity"
    case .failedToCreateToken(let type):
      return "Failed to create \(type.rawValue) token"
    case .requestUnavailable:
      return "Request context unavailable"
    case .configurationError(let message):
      return "Configuration error: \(message)"
    case .unexpected(let message):
      return "Unexpected error: \(message)"
    }
  }
}
