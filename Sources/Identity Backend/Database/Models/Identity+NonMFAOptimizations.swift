import Foundation
import Records
import Dependencies
import EmailAddress

// MARK: - Selection Types for API Key Authentication

@Selection
package struct ApiKeyWithIdentity: Sendable {
    package let apiKey: IdentityApiKey
    package let identity: Database.Identity
}

@Selection
package struct TokenWithIdentity: Sendable {
    package let token: Database.Identity.Token
    package let identity: Database.Identity
}

@Selection  
package struct EmailChangeRequestWithIdentity: Sendable {
    package let emailChangeRequest: Database.Identity.Email.Change.Request
    package let identity: Database.Identity
    package let currentEmail: String
}

@Selection
package struct ProfileWithIdentity: Sendable {
    package let profile: Database.Identity.Profile
    package let identity: Database.Identity
    package let hasApiKeys: Bool
}

// MARK: - API Key Optimizations

extension IdentityApiKey {
    
    /// Single query to validate API key and get associated identity
    /// Replaces: findByKey + separate identity lookup
    package static func authenticateWithKey(_ key: String) async throws -> ApiKeyWithIdentity? {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        return try await db.write { db in
            // Get API key with identity in single query
            let result = try await IdentityApiKey
                .where { $0.key.eq(key) }
                .where { $0.isActive.eq(true) }
                .join(Database.Identity.all) { apiKey, identity in
                    apiKey.identityId.eq(identity.id)
                }
                .select { apiKey, identity in
                    ApiKeyWithIdentity.Columns(
                        apiKey: apiKey,
                        identity: identity
                    )
                }
                .fetchOne(db)
            
            // Update last used timestamp atomically if found
            if let result = result {
                try await IdentityApiKey
                    .where { $0.id.eq(result.apiKey.id) }
                    .update { apiKey in
                        apiKey.lastUsedAt = date()
                    }
                    .execute(db)
            }
            
            return result
        }
    }
    
    /// Batch deactivate API keys
    package static func deactivateMultiple(ids: [UUID]) async throws {
        @Dependency(\.defaultDatabase) var db
        
        guard !ids.isEmpty else { return }
        
        try await db.write { db in
            // TODO: When swift-structured-queries supports WHERE IN, replace with:
            // .where { $0.id.in(ids) }
            for id in ids {
                try await IdentityApiKey
                    .where { $0.id.eq(id) }
                    .update { apiKey in
                        apiKey.isActive = false
                    }
                    .execute(db)
            }
        }
    }
}

// MARK: - Token Optimizations

extension Database.Identity.Token {
    
    /// Validate token and get associated identity in single query
    /// Replaces: findValid + separate identity lookup
    package static func validateWithIdentity(value: String, type: TokenType) async throws -> TokenWithIdentity? {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Database.Identity.Token
                .where { token in
                    token.value.eq(value)
                        .and(token.type.eq(type))
                        .and(#sql("\(token.validUntil) > CURRENT_TIMESTAMP"))
                }
                .join(Database.Identity.all) { token, identity in
                    token.identityId.eq(identity.id)
                }
                .select { token, identity in
                    TokenWithIdentity.Columns(
                        token: token,
                        identity: identity
                    )
                }
                .fetchOne(db)
        }
    }
    
    /// Batch cleanup expired tokens with count
    package static func cleanupExpiredWithCount() async throws -> Int {
        @Dependency(\.defaultDatabase) var db
        
        // First get count of expired tokens
        let count = try await db.read { db in
            try await Database.Identity.Token
                .where { token in
                    #sql("\(token.validUntil) <= CURRENT_TIMESTAMP")
                }
                .fetchCount(db)
        }
        
        // Then delete them
        if count > 0 {
            try await db.write { db in
                try await Database.Identity.Token
                    .delete()
                    .where { token in
                        #sql("\(token.validUntil) <= CURRENT_TIMESTAMP")
                    }
                    .execute(db)
            }
        }
        
        return count
    }
}

// MARK: - Email Change Request Optimizations

extension Database.Identity.Email.Change.Request {
    
    /// Find email change request by token with identity data
    /// Replaces: findByToken + separate identity lookup
    package static func findByTokenWithIdentity(_ token: String) async throws -> EmailChangeRequestWithIdentity? {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Database.Identity.Email.Change.Request
                .join(Database.Identity.Token.all) { request, tokenEntity in
                    request.identityId.eq(tokenEntity.identityId)
                        .and(tokenEntity.value.eq(token))
                        .and(tokenEntity.type.eq(Database.Identity.Token.TokenType.emailChange))
                        .and(#sql("\(tokenEntity.validUntil) > CURRENT_TIMESTAMP"))
                }
                .join(Database.Identity.all) { request, _, identity in
                    request.identityId.eq(identity.id)
                }
                .select { request, _, identity in
                    EmailChangeRequestWithIdentity.Columns(
                        emailChangeRequest: request,
                        identity: identity,
                        currentEmail: identity.emailString
                    )
                }
                .fetchOne(db)
        }
    }
}

// MARK: - Profile Optimizations

extension Database.Identity.Profile {
    
    /// Get or create profile with identity data and API key status
    /// Useful for profile management pages
    package static func getOrCreateWithIdentity(for identityId: UUID) async throws -> ProfileWithIdentity {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.uuid) var uuid
        
        // First try to get existing profile with identity
        if let existing = try await db.read({ db in
            try await Database.Identity.Profile
                .where { $0.identityId.eq(identityId) }
                .join(Database.Identity.all) { profile, identity in
                    profile.identityId.eq(identity.id)
                }
                .leftJoin(IdentityApiKey.all) { profile, _, apiKey in
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
        let newProfile = Database.Identity.Profile(
            id: uuid(),
            identityId: identityId,
            displayName: nil
        )
        
        try await db.write { [newProfile] db in
            try await Database.Identity.Profile.insert { newProfile }.execute(db)
        }
        
        // Fetch with identity data
        guard let result = try await db.read({ db in
            try await Database.Identity.Profile
                .where { $0.id.eq(newProfile.id) }
                .join(Database.Identity.all) { profile, identity in
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
            throw Identity.Backend.ValidationError.internalError/*("Failed to create profile")*/
        }
        
        return result
    }
}

// MARK: - Session Management Optimizations

extension Database.Identity {
    
//    /// Batch invalidate sessions for multiple identities
//    /// Returns count of identities updated
//    package static func invalidateSessionsBatch(identityIds: [UUID]) async throws -> Int {
//        @Dependency(\.defaultDatabase) var db
//        @Dependency(\.date) var date
//        
//        guard !identityIds.isEmpty else { return 0 }
//        
//        var updatedCount = 0
//        
//        try await db.write { db in
//            // TODO: When swift-structured-queries supports WHERE IN, replace with single query
//            for identityId in identityIds {
//                try await Database.Identity
//                    .where { $0.id.eq(identityId) }
//                    .update { identity in
//                        identity.sessionVersion = identity.sessionVersion + 1
//                        identity.updatedAt = date()
//                    }
//                    .execute(db)
//                updatedCount += 1
//            }
//        }
//        
//        return updatedCount
//    }
    
    /// Check multiple emails exist in single query
    /// Returns dictionary of email -> exists
    package static func emailsExist(_ emails: [EmailAddress]) async throws -> [EmailAddress: Bool] {
        @Dependency(\.defaultDatabase) var db
        
        guard !emails.isEmpty else { return [:] }
        
        // Get all existing emails in one query
        let existingEmails = try await db.read { db in
            var results: Set<String> = []
            for email in emails {
                let exists = try await Database.Identity
                    .where { $0.emailString.eq(email.rawValue) }
                    .fetchCount(db) > 0
                if exists {
                    results.insert(email.rawValue)
                }
            }
            return results
        }
        
        // Build result dictionary
        var result: [EmailAddress: Bool] = [:]
        for email in emails {
            result[email] = existingEmails.contains(email.rawValue)
        }
        
        return result
    }
}

// MARK: - Verification Status Batch Operations

//extension Database.Identity {
//    
//    /// Update email verification status for multiple identities
//    package static func updateVerificationStatusBatch(
//        identityIds: [UUID],
//        status: EmailVerificationStatus
//    ) async throws -> Int {
//        @Dependency(\.defaultDatabase) var db
//        @Dependency(\.date) var date
//        
//        guard !identityIds.isEmpty else { return 0 }
//        
//        var updatedCount = 0
//        
//        try await db.write { db in
//            for identityId in identityIds {
//                try await Database.Identity
//                    .where { $0.id.eq(identityId) }
//                    .update { identity in
//                        identity.emailVerificationStatus = status
//                        identity.updatedAt = date()
//                    }
//                    .execute(db)
//                updatedCount += 1
//            }
//        }
//        
//        return updatedCount
//    }
//}
