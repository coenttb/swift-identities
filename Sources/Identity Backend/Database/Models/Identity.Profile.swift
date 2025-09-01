//
//  Identity.Profile.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import Records
import Dependencies

extension Database.Identity {
    @Table("identity_profiles")
    public struct Profile: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public let identityId: UUID
        public var displayName: String?
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        
        package init(
            id: UUID,
            identityId: UUID,
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
            identityId: UUID,
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

extension Database.Identity.Profile {
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

extension Database.Identity.Profile {
    public static func findByIdentity(_ identityId: UUID) -> Where<Database.Identity.Profile> {
        Self.where { $0.identityId.eq(identityId) }
    }
}
