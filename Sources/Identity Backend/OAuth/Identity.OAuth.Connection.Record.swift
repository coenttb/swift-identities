//
//  Identity.OAuth.Connection.Record.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2025.
//

import Foundation
import Records
import IdentitiesTypes
import Dependencies

extension Identity.OAuth.Connection {
    @Table("oauth_connections")
    public struct Record: Sendable {
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
        
        @Column("scopes")
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
            id: UUID,
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

// MARK: - Query Helpers

extension Identity.OAuth.Connection.Record {
    /// Query helper to find connection by identity and provider
    /// This is used multiple times, so keeping it as a composable query helper
    package static func findByIdentityProvider(
        _ identityId: Identity.ID,
        _ provider: String
    ) -> Where<Identity.OAuth.Connection.Record> {
        Self.where { connection in
            connection.identityId.eq(identityId)
                .and(connection.provider.eq(provider))
        }
    }
    
    /// Query helper to find all connections for an identity
    package static func findByIdentity(
        _ identityId: Identity.ID
    ) -> Where<Identity.OAuth.Connection.Record> {
        Self.where { $0.identityId.eq(identityId) }
    }
}


extension Identity.OAuth.Connection {
    public init(from oauthConnection: Identity.OAuth.Connection.Record) {
        self = Identity.OAuth.Connection(
            provider: oauthConnection.provider,
            providerUserId: oauthConnection.providerUserId,
            connectedAt: oauthConnection.createdAt,
            scopes: oauthConnection.scopes
        )
    }
}
