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

// MARK: - UPSERT Operations

extension Identity.Profile.Record {
    /// Upsert based on identityId (create if doesn't exist, update if exists)
    /// Uses the UNIQUE constraint on identityId for conflict detection
    package static func upsertByIdentityId(
        _ profile: Identity.Profile.Record
    ) -> InsertOf<Identity.Profile.Record> {
        return Self
            .insert {
                profile
            } onConflict: { cols in
                cols.identityId
            } doUpdate: { updates, excluded in
                updates.displayName = excluded.displayName
                updates.updatedAt = excluded.updatedAt
            }
    }
}

