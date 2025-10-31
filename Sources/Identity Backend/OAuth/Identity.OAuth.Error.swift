//
//  File.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 12/09/2025.
//

import Foundation

extension Identity.OAuth {
  public enum Error: Swift.Error, LocalizedError {
    case invalidState
    case providerNotFound(String)
    case userInfoExtractionFailed
    case tokenExchangeFailed
    case missingEmail
    case accountAlreadyLinked
    case tokenExpired

    public var errorDescription: String? {
      switch self {
      case .invalidState:
        return "Invalid or expired OAuth state token"
      case .providerNotFound(let provider):
        return "OAuth provider '\(provider)' not found"
      case .userInfoExtractionFailed:
        return "Failed to extract user information from OAuth provider"
      case .tokenExchangeFailed:
        return "Failed to exchange authorization code for access token"
      case .missingEmail:
        return "OAuth provider did not provide an email address"
      case .accountAlreadyLinked:
        return "This OAuth account is already linked to another user"
      case .tokenExpired:
        return "Token expired"
      }
    }
  }
}
