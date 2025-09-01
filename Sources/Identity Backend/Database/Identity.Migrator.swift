//
//  Identity.Migrator.swift
//  coenttb-identities
//
//  Database migrations for Identity system using Database.Migrator
//

import Foundation
import Records
import Dependencies
import Logging
import Crypto
import EmailAddress
import Vapor

extension Identity.Backend {
    /// Returns a configured Database.Migrator with all Identity migrations registered.
    ///
    /// Usage:
    /// ```swift
    /// let migrator = Identity.Backend.migrator()
    /// try await migrator.migrate(database)
    /// ```
    public static func migrator() -> Records.Database.Migrator {
        var migrator = Records.Database.Migrator()
        
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
                    "isActive" INTEGER NOT NULL DEFAULT 1 CHECK ("isActive" IN (0, 1)),
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
                    "isConfirmed" INTEGER NOT NULL DEFAULT 0 CHECK ("isConfirmed" IN (0, 1)),
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
                    "isUsed" INTEGER NOT NULL DEFAULT 0 CHECK ("isUsed" IN (0, 1)),
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
                WHERE "isUsed" = 0
            """)
        }
        
        // Development test user
        #if DEBUG
        migrator.registerMigration("create_test_user") { db in
            try await createTestUser(using: db)
        }
        #endif
        
        return migrator
    }
    
    #if DEBUG
    /// Creates a test user for development purposes
    private static func createTestUser(using db: any Records.Database.Connection.`Protocol`) async throws {
        @Dependency(\.logger) var logger
        
        let testEmail = "test@test.com"
        let testPassword = "test"
        
        // Check if test user already exists
        let existingUser = try await Database.Identity
            .where { $0.emailString == testEmail }
            .fetchOne(db)
        
        if existingUser == nil {
            // Hash the password
            let passwordHash = try Bcrypt.hash(testPassword)
            
            // Create the test user with verified email
            let testUser = Database.Identity(
                id: UUID(),
                email: try .init(testEmail),
                passwordHash: passwordHash,
                emailVerificationStatus: .verified,
                sessionVersion: 0,
                createdAt: Date(),
                updatedAt: Date(),
                lastLoginAt: nil
            )
            
            try await Database.Identity.insert { testUser }.execute(db)
            
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
    #endif
}
