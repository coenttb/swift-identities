//
//  Database.OAuthConnection.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2025.
//

import Foundation
import Records
import IdentitiesTypes
import Dependencies

extension Database {
    @Table("oauth_connections")
    public struct OAuthConnection: Sendable {
        public var id: UUID
        
        @Column("identity_id")
        public var identityId: Identity.ID
        
        @Column("provider")
        public var provider: String
        
        @Column("provider_user_id")
        public var providerUserId: String
        
        @Column("access_token")
        public var accessToken: String // Encrypted
        
        @Column("refresh_token")
        public var refreshToken: String? // Encrypted
        
        @Column("token_type")
        public var tokenType: String?
        
        @Column("expires_at")
        public var expiresAt: Date?
        
        @Column("scopes", as: [String]?.PostgresJSONB.self)
        public var scopes: [String]?
        
        @Column("user_info")
        public var userInfo: Data? // JSON encoded provider-specific data
        
        @Column("created_at")
        public var createdAt: Date
        
        @Column("updated_at")
        public var updatedAt: Date
        
        @Column("last_used_at")
        public var lastUsedAt: Date?
        
        public init(
            id: UUID = UUID(),
            identityId: Identity.ID,
            provider: String,
            providerUserId: String,
            accessToken: String,
            refreshToken: String? = nil,
            tokenType: String? = "Bearer",
            expiresAt: Date? = nil,
            scopes: [String]? = nil,
            userInfo: Data? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            lastUsedAt: Date? = nil
        ) {
            self.id = id
            self.identityId = identityId
            self.provider = provider
            self.providerUserId = providerUserId
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.tokenType = tokenType
            self.expiresAt = expiresAt
            self.scopes = scopes
            self.userInfo = userInfo
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.lastUsedAt = lastUsedAt
        }
    }
}

// MARK: - Queries

extension Database.OAuthConnection {
    /// Find connection by provider and provider user ID
    public static func find(
        provider: String,
        providerUserId: String
    ) async throws -> Database.OAuthConnection? {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Self.all
                .where { connection in
                    connection.provider.eq(provider)
                        .and(connection.providerUserId.eq(providerUserId))
                }
                .fetchOne(db)
        }
    }
    
    /// Find all connections for an identity
    public static func findAll(
        identityId: Identity.ID
    ) async throws -> [Database.OAuthConnection] {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Self.all
                .where { $0.identityId.eq(identityId) }
                .fetchAll(db)
        }
    }
    
    /// Find connection for identity and provider
    public static func find(
        identityId: Identity.ID,
        provider: String
    ) async throws -> Database.OAuthConnection? {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Self.all
                .where { connection in
                    connection.identityId.eq(identityId)
                        .and(connection.provider.eq(provider))
                }
                .fetchOne(db)
        }
    }
    
    /// Update last used timestamp
    public func updateLastUsed() async throws {
        @Dependency(\.defaultDatabase) var db
        
        try await db.write { db in
            try await Self.all
                .where { $0.id.eq(self.id) }
                .update { connection in
                    connection.lastUsedAt = Date()
                    connection.updatedAt = Date()
                }
                .execute(db)
        }
    }
    
    /// Update tokens
    public func updateTokens(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil
    ) async throws {
        @Dependency(\.defaultDatabase) var db
        
        try await db.write { db in
            try await Self.all
                .where { $0.id.eq(self.id) }
                .update { connection in
                    connection.accessToken = accessToken
                    if let refreshToken {
                        connection.refreshToken = refreshToken
                    }
                    connection.expiresAt = expiresAt
                    connection.updatedAt = Date()
                }
                .execute(db)
        }
    }
}

extension Identity.Client.OAuth.OAuthConnection {
    public init(from oauthConnection: Database.OAuthConnection) {
        self = Identity.Client.OAuth.OAuthConnection(
            provider: oauthConnection.provider,
            providerUserId: oauthConnection.providerUserId,
            connectedAt: oauthConnection.createdAt,
            scopes: oauthConnection.scopes
        )
    }
}
