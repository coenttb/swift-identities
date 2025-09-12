//
//  Identity.Profile.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import Records
import Dependencies
import IdentitiesTypes

extension Identity {
    public enum Profile {}
}

extension Identity.Profile {
    @Table("identity_profiles")
    public struct Record: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public let identityId: Identity.ID
        public var displayName: String?
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        
        package init(
            id: UUID,
            identityId: Identity.ID,
            displayName: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.identityId = identityId
            self.displayName = displayName
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
        
        package init(
            identityId: Identity.ID,
            displayName: String? = nil
        ) {
            @Dependency(\.uuid) var uuid
            self.id = uuid()
            self.identityId = identityId
            self.displayName = displayName
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
}

// MARK: - Validation


extension Identity.Profile.Record {
    package static func validateDisplayName(_ displayName: String) throws {
        // Check length (1-100 characters)
        guard displayName.count >= 1 && displayName.count <= 100 else {
            throw ValidationError.invalidLength
        }
        
        // Display names can contain any characters except control characters
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyDisplayName
        }
    }
    
    package struct ValidationError: Swift.Error, LocalizedError {
        let message: String
        
        static let invalidLength = ValidationError(message: "Display name must be between 1 and 100 characters")
        static let emptyDisplayName = ValidationError(message: "Display name cannot be empty or just whitespace")
        
        public var errorDescription: String? {
            message
        }
    }
}

// MARK: - Query Helpers

extension Identity.Profile.Record {
    public static func findByIdentity(_ identityId: Identity.ID) -> Where<Identity.Profile.Record> {
        Self.where { $0.identityId.eq(identityId) }
    }
}

extension Identity.Profile.Record {
    
    /// Get or create profile with identity data and API key status
    /// Useful for profile management pages
    package static func getOrCreateWithIdentity(for identityId: Identity.ID) async throws -> ProfileWithIdentity {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        
        // First try to get existing profile with identity
        if let existing = try await db.read({ db in
            try await Identity.Profile.Record
                .where { $0.identityId.eq(identityId) }
                .join(Identity.Record.all) { profile, identity in
                    profile.identityId.eq(identity.id)
                }
                .leftJoin(Identity.Authentication.ApiKey.Record.all) { profile, _, apiKey in
                    profile.identityId.eq(apiKey.identityId)
                        .and(apiKey.isActive.eq(true))
                }
                .group { profile, identity, _ in
                    (profile.id, identity.id)
                }
                .select { profile, identity, apiKey in
                    ProfileWithIdentity.Columns(
                        profile: profile,
                        identity: identity,
                        hasApiKeys: apiKey.id.count() > 0
                    )
                }
                .fetchOne(db)
        }) {
            return existing
        }
        
        // Create new profile
        let newProfile = Identity.Profile.Record(
            id: uuid(),
            identityId: identityId,
            displayName: nil
        )
        
        try await db.write { [newProfile] db in
            try await Identity.Profile.Record.insert { newProfile }.execute(db)
        }
        
        // Fetch with identity data
        guard let result = try await db.read({ db in
            try await Identity.Profile.Record
                .where { $0.id.eq(newProfile.id) }
                .join(Identity.Record.all) { profile, identity in
                    profile.identityId.eq(identity.id)
                }
                .select { profile, identity in
                    ProfileWithIdentity.Columns(
                        profile: profile,
                        identity: identity,
                        hasApiKeys: false
                    )
                }
                .fetchOne(db)
        }) else {
            throw Identity.Authentication.ValidationError.internalError/*("Failed to create profile")*/
        }
        
        return result
    }
}

@Selection
package struct ProfileWithIdentity: Sendable {
    package let profile: Identity.Profile.Record
    package let identity: Identity.Record
    package let hasApiKeys: Bool
}
