//
//  Identity.Profile+Queries.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import Records
import Dependencies

// MARK: - Database Operations

extension Database.Identity.Profile {
    
    // Async initializer that creates and persists to database
    package init(
        identityId: UUID,
        displayName: String? = nil
    ) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        
        // Validate display name if provided
        if let displayName = displayName {
            try Self.validateDisplayName(displayName)
        }
        
        self.init(
            id: uuid(),
            identityId: identityId,
            displayName: displayName
        )
        
        let `self` = self
        
        _ = try await db.write { db in
            try await Database.Identity.Profile.insert { `self` }
                .execute(db)
        }
    }
    
    package static func getByIdentity(_ identityId: UUID) async throws -> Database.Identity.Profile? {
        @Dependency(\.defaultDatabase) var db
        return try await db.read { db in
            try await Database.Identity.Profile.findByIdentity(identityId)
                .fetchOne(db)
        }
    }
    
    package static func getOrCreate(for identityId: UUID) async throws -> Database.Identity.Profile {
        @Dependency(\.defaultDatabase) var db
        
        // Check if profile exists
        if let existing = try await getByIdentity(identityId) {
            return existing
        }
        
        // Create new profile
        return try await Database.Identity.Profile(
            identityId: identityId
        )
    }
    
    
    package mutating func updateDisplayName(_ displayName: String?) async throws {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        self.displayName = displayName
        self.updatedAt = date()
        let updatedDisplayName = self.displayName
        let updatedAt = self.updatedAt
        let id = self.id
        
        try await db.write { db in
            try await Database.Identity.Profile
                .update { profile in
                    profile.displayName = updatedDisplayName
                    profile.updatedAt = updatedAt
                }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
    
}
