//
//  Identity.OAuth.State.Manager.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2025.
//

import Foundation
import Dependencies
import IdentitiesTypes
import Records

extension Identity.OAuth.State {
    /// Manages OAuth state tokens for CSRF protection
    public actor Manager {
        @Dependency(\.defaultDatabase) private var database
        
        public init() {}
        
        /// Generate and store a new OAuth state
        public func generateState(
            for provider: String,
            redirectURI: String,
            identityId: Identity.ID? = nil
        ) async throws -> String {
            let stateValue = Identity.OAuth.State.Record.generateState()
            
            let state = Identity.OAuth.State.Record(
                state: stateValue,
                provider: provider,
                redirectURI: redirectURI,
                identityId: identityId
            )
            
            try await database.write { db in
                try await Identity.OAuth.State.Record.insert { state }.execute(db)
            }
            
            return stateValue
        }
        
        /// Validate and consume an OAuth state
        public func validateState(_ state: String) async throws -> Identity.OAuth.State.Record {
            guard let oauthState = try await Identity.OAuth.State.Record.validate(state) else {
                throw Identity.OAuth.Error.invalidState
            }
            
            return oauthState
        }
        
        /// Clean up expired states (should be called periodically)
        public func cleanupExpiredStates() async throws {
            try await Identity.OAuth.State.Record.cleanupExpired()
        }
    }
}

