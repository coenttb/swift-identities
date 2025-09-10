//
//  OAuthStateManager.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2025.
//

import Foundation
import Dependencies
import IdentitiesTypes
import Records

/// Manages OAuth state tokens for CSRF protection
public actor OAuthStateManager {
    @Dependency(\.defaultDatabase) private var database
    
    public init() {}
    
    /// Generate and store a new OAuth state
    public func generateState(
        for provider: String,
        redirectURI: String,
        identityId: Identity.ID? = nil
    ) async throws -> String {
        let stateValue = Database.OAuthState.generateState()
        
        let state = Database.OAuthState(
            state: stateValue,
            provider: provider,
            redirectURI: redirectURI,
            identityId: identityId
        )
        
        try await database.write { db in
            try await Database.OAuthState.insert { state }.execute(db)
        }
        
        return stateValue
    }
    
    /// Validate and consume an OAuth state
    public func validateState(_ state: String) async throws -> Database.OAuthState {
        guard let oauthState = try await Database.OAuthState.validate(state) else {
            throw OAuthError.invalidState
        }
        
        return oauthState
    }
    
    /// Clean up expired states (should be called periodically)
    public func cleanupExpiredStates() async throws {
        try await Database.OAuthState.cleanupExpired()
    }
}

// MARK: - Errors

public enum OAuthError: Error, LocalizedError {
    case invalidState
    case providerNotFound(String)
    case userInfoExtractionFailed
    case tokenExchangeFailed
    case missingEmail
    case accountAlreadyLinked
    
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
        }
    }
}
