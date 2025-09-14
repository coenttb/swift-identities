//
//  Identity.Migrator.swift
//  coenttb-identities
//
//  Database migrations for Identity system using Migrator
//

import Foundation
import Records
import Dependencies
import Logging
import Crypto
import EmailAddress
import Vapor

extension Identity.Backend {
    /// Returns a configured Migrator with all Identity migrations registered.
    ///
    /// Usage:
    /// ```swift
    /// let migrator = Identity.Backend.migrator()
    /// try await migrator.migrate(database)
    /// ```
    public static func migrator() -> Records.Database.Migrator {
        var migrator = Records.Database.Migrator()
        @Dependency(\.logger) var logger
        
        // Core identity table
        migrator.registerMigration("create_identities_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS identities (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    email TEXT NOT NULL UNIQUE,
                    "passwordHash" TEXT NOT NULL,
                    "emailVerificationStatus" TEXT NOT NULL DEFAULT 'unverified',
                    "sessionVersion" INTEGER NOT NULL DEFAULT 0,
                    "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    "updatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    "lastLoginAt" TIMESTAMP
                )
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identities_email_idx ON identities(email)
            """)
        }
        
        // Identity tokens table
        migrator.registerMigration("create_identity_tokens_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS identity_tokens (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    value TEXT NOT NULL UNIQUE,
                    "validUntil" TIMESTAMP NOT NULL,
                    "identityId" UUID NOT NULL REFERENCES identities(id) ON DELETE CASCADE,
                    type TEXT NOT NULL,
                    "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    "lastUsedAt" TIMESTAMP
                )
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_tokens_value_idx ON identity_tokens(value)
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_tokens_identityId_idx ON identity_tokens("identityId")
            """)
        }
        
        // API keys table
        migrator.registerMigration("create_identity_api_keys_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS identity_api_keys (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    name TEXT NOT NULL,
                    key TEXT NOT NULL UNIQUE,
                    scopes TEXT[] NOT NULL DEFAULT '{}',
                    "identityId" UUID NOT NULL REFERENCES identities(id) ON DELETE CASCADE,
                    "isActive" BOOLEAN NOT NULL DEFAULT TRUE,
                    "rateLimit" INTEGER NOT NULL DEFAULT 1000,
                    "validUntil" TIMESTAMP NOT NULL,
                    "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    "lastUsedAt" TIMESTAMP
                )
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_api_keys_key_idx ON identity_api_keys(key)
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_api_keys_identityId_idx ON identity_api_keys("identityId")
            """)
        }
        
        // Account deletion tracking table
        migrator.registerMigration("create_identity_deletions_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS identity_deletions (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    "identityId" UUID NOT NULL REFERENCES identities(id) ON DELETE CASCADE,
                    "requestedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    reason TEXT,
                    "confirmedAt" TIMESTAMP,
                    "cancelledAt" TIMESTAMP,
                    "scheduledFor" TIMESTAMP NOT NULL
                )
            """)
            
            try await db.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS identity_deletions_identityId_idx ON identity_deletions("identityId")
            """)
        }
        
        // Email change requests table
        migrator.registerMigration("create_identity_email_change_requests_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS identity_email_change_requests (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    "identityId" UUID NOT NULL REFERENCES identities(id) ON DELETE CASCADE,
                    "newEmail" TEXT NOT NULL,
                    "verificationToken" TEXT NOT NULL UNIQUE,
                    "requestedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    "expiresAt" TIMESTAMP NOT NULL,
                    "confirmedAt" TIMESTAMP,
                    "cancelledAt" TIMESTAMP
                )
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_email_change_requests_token_idx 
                ON identity_email_change_requests("verificationToken")
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_email_change_requests_identityId_idx 
                ON identity_email_change_requests("identityId")
            """)
            
            // Add partial unique index to ensure only one pending email change per identity
            try await db.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS identity_email_change_requests_identityId_pending_idx 
                ON identity_email_change_requests("identityId") 
                WHERE "confirmedAt" IS NULL AND "cancelledAt" IS NULL
            """)
        }
        
        // User profiles table
        migrator.registerMigration("create_identity_profiles_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS identity_profiles (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    "identityId" UUID NOT NULL UNIQUE REFERENCES identities(id) ON DELETE CASCADE,
                    "displayName" TEXT,
                    "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    "updatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_profiles_identityId_idx ON identity_profiles("identityId")
            """)
        }
        
        // TOTP 2FA table
        migrator.registerMigration("create_identity_totp_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS identity_totp (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    "identityId" UUID NOT NULL UNIQUE REFERENCES identities(id) ON DELETE CASCADE,
                    secret TEXT NOT NULL,
                    "isConfirmed" BOOLEAN NOT NULL DEFAULT FALSE,
                    algorithm VARCHAR(10) NOT NULL DEFAULT 'SHA1',
                    digits INTEGER NOT NULL DEFAULT 6,
                    "timeStep" INTEGER NOT NULL DEFAULT 30,
                    "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    "confirmedAt" TIMESTAMP,
                    "lastUsedAt" TIMESTAMP,
                    "usageCount" INTEGER NOT NULL DEFAULT 0
                )
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_totp_identityId_idx ON identity_totp("identityId")
            """)
        }
        
        // Backup codes table for 2FA
        migrator.registerMigration("create_identity_backup_codes_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS identity_backup_codes (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    "identityId" UUID NOT NULL REFERENCES identities(id) ON DELETE CASCADE,
                    "codeHash" TEXT NOT NULL,
                    "isUsed" BOOLEAN NOT NULL DEFAULT FALSE,
                    "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    "usedAt" TIMESTAMP
                )
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_backup_codes_identityId_idx 
                ON identity_backup_codes("identityId")
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS identity_backup_codes_unused_idx 
                ON identity_backup_codes("identityId", "isUsed") 
                WHERE "isUsed" = false
            """)
        }
        
        // Development test user
#if DEBUG
        @Sendable func createTestUser(using db: any Records.Database.Connection.`Protocol`) async throws {
            @Dependency(\.logger) var logger
            
            let testEmail: EmailAddress = try! .init("test@test.com")
            let testPassword = "test"
            
            // Check if test user already exists
            let existingUser = try await Identity.Record
                .where { $0.email == testEmail }
                .fetchOne(db)
            
            if existingUser == nil {
                // Hash the password
                let passwordHash = try Bcrypt.hash(testPassword)
                
                // Create the test user with verified email
                @Dependency(\.uuid) var uuid
                let id = Identity.ID(uuid())
                
                let testUser = Identity.Record(
                    id: id,
                    email: testEmail,
                    passwordHash: passwordHash,
                    emailVerificationStatus: .verified,
                    sessionVersion: 0,
                    createdAt: Date(),
                    updatedAt: Date(),
                    lastLoginAt: nil
                )
                
                try await Identity.Record.insert { testUser }.execute(db)
                
                logger.info("Test user created", metadata: [
                    "component": "Identity.Database",
                    "environment": "DEBUG",
                    "email": "test@test.com"
                ])
            } else {
                logger.debug("Test user already exists", metadata: [
                    "component": "Identity.Database",
                    "environment": "DEBUG",
                    "email": "test@test.com"
                ])
            }
        }
        
        migrator.registerMigration("create_test_user") { db in
            try await createTestUser(using: db)
        }
#endif
        
        
        // OAuth connections table
        migrator.registerMigration("create_oauth_connections_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS oauth_connections (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    identity_id UUID NOT NULL REFERENCES identities(id) ON DELETE CASCADE,
                    provider VARCHAR(50) NOT NULL,
                    provider_user_id VARCHAR(255) NOT NULL,
                    access_token TEXT NOT NULL,
                    refresh_token TEXT,
                    token_type VARCHAR(50),
                    expires_at TIMESTAMP,
                    scopes JSONB,
                    user_info BYTEA,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    last_used_at TIMESTAMP,
                    UNIQUE(provider, provider_user_id)
                )
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS oauth_connections_identity_idx ON oauth_connections(identity_id)
            """)
            
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS oauth_connections_provider_idx ON oauth_connections(provider, provider_user_id)
            """)
        }
        
        // OAuth states table for CSRF protection
        migrator.registerMigration("create_oauth_states_table") { db in
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS oauth_states (
                    state VARCHAR(255) PRIMARY KEY,
                    provider VARCHAR(50) NOT NULL,
                    redirect_uri TEXT NOT NULL,
                    identity_id UUID REFERENCES identities(id) ON DELETE CASCADE,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    expires_at TIMESTAMP NOT NULL
                )
            """)
            
            // Index for cleanup of expired states
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS oauth_states_expires_idx ON oauth_states(expires_at)
            """)
        }
        
        // Performance optimization indexes
        migrator.registerMigration("add_performance_indexes") { db in
            @Dependency(\.logger) var logger
            
            logger.info("Adding performance indexes for Identity tables", metadata: [
                "component": "Identity.Database",
                "migration": "add_performance_indexes"
            ])
            
            // Composite index for authentication queries
            try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_identities_email_verification 
            ON identities(email, "emailVerificationStatus");
        """)
            
            // Index for TOTP lookups - composite index for identity + confirmed status
            try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_identity_totp_confirmed 
            ON identity_totp("identityId", "isConfirmed") 
            WHERE "isConfirmed" = true;
        """)
            
            // Index for unused backup codes lookup
            try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_backup_codes_unused 
            ON identity_backup_codes("identityId", "isUsed") 
            WHERE "isUsed" = false;
        """)
            
            // Index for active API keys
            try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_api_keys_active 
            ON identity_api_keys("identityId", "isActive") 
            WHERE "isActive" = true;
        """)
            
            // Index for API key lookups by key hash
            try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_api_keys_hash 
            ON identity_api_keys(key) 
            WHERE "isActive" = true;
        """)
            
            // Index for email change requests
            try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_email_change_requests_identity 
            ON identity_email_change_requests("identityId") 
            WHERE "confirmedAt" IS NULL;
        """)
            
            // Index for profile lookups
            try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_profiles_identity 
            ON identity_profiles("identityId");
        """)
            
            // Index for deletion requests
            try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_deletions_identity_pending 
            ON identity_deletions("identityId") 
            WHERE "confirmedAt" IS NULL;
        """)
            
            logger.info("Performance indexes added successfully", metadata: [
                "component": "Identity.Database",
                "migration": "add_performance_indexes"
            ])
        }
        
        // Additional performance optimization indexes
        migrator.registerMigration("add_performance_indexes_v2") { db in
            @Dependency(\.logger) var logger
            
            logger.info("Adding additional performance indexes for Identity tables", metadata: [
                "component": "Identity.Database",
                "migration": "add_performance_indexes_v2"
            ])
            
            // Partial index for verified email lookups (common in authentication)
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS idx_identities_email_verified 
                ON identities(email) 
                WHERE "emailVerificationStatus" = 'verified'
            """)
            
            // Index for session token lookups with type and validity
            // Note: We include validUntil in the index but don't use it in WHERE clause
            // because CURRENT_TIMESTAMP is not immutable for partial indexes
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS idx_tokens_type_valid 
                ON identity_tokens(value, type, "validUntil")
            """)
            
            // Composite index for OAuth connection lookups
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS idx_oauth_connections_provider_identity 
                ON oauth_connections(provider, identity_id)
            """)
            
            // Index for email change request token lookups
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS idx_email_change_token 
                ON identity_email_change_requests("verificationToken") 
                WHERE "confirmedAt" IS NULL
            """)
            
            // Index for active sessions by identity (for logout all)
            // Note: We include validUntil in the index but don't use it in WHERE clause
            // because CURRENT_TIMESTAMP is not immutable for partial indexes
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS idx_tokens_identity_active 
                ON identity_tokens("identityId", type, "validUntil")
            """)
            
            logger.info("Additional performance indexes added successfully", metadata: [
                "component": "Identity.Database",
                "migration": "add_performance_indexes_v2"
            ])
        }
        
        
        
        // Add unique constraint for OAuth connections per identity
        migrator.registerMigration("add_oauth_connections_unique_constraint") { db in
            logger.info("Adding unique constraint for OAuth connections", metadata: [
                "component": "Identity.Database",
                "migration": "add_oauth_connections_unique_constraint"
            ])
            
            // Add unique constraint on (identity_id, provider) to ensure
            // only one connection per provider per identity
            try await db.execute("""
                ALTER TABLE oauth_connections
                ADD CONSTRAINT oauth_connections_identity_provider_unique
                UNIQUE (identity_id, provider)
            """)
            
            logger.info("OAuth connections unique constraint added successfully", metadata: [
                "component": "Identity.Database",
                "migration": "add_oauth_connections_unique_constraint"
            ])
        }
        
        return migrator
    }
}
