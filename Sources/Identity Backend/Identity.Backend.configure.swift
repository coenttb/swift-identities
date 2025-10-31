//
//  Identity.Backend.configure.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Records
import Dependencies
import Logging
import Vapor

extension Identity.Backend {
    /// Configures a Vapor application as an Identity backend/provider.
    ///
    /// This function sets up middleware and routes for an Identity provider server.
    /// The database should already be configured by the application before calling this.
    ///
    /// - Parameter application: The Vapor application to configure
    /// - Throws: Any errors during configuration
    public static func configure(
        _ application: Vapor.Application,
        runMigrations: Bool
    ) async throws {
        @Dependency(\.logger) var logger
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.envVars) var envVars

        logger.trace("Configuring Identity Backend")

        // SECURITY: Validate encryption key in production
        // The encryption key is used for TOTP secrets and OAuth tokens
        let isProduction = application.environment == .production
        let hasEncryptionKey = !envVars.encryptionKey.isEmpty

        if isProduction && !hasEncryptionKey {
            logger.critical("SECURITY VIOLATION: IDENTITIES_ENCRYPTION_KEY must be set in production", metadata: [
                "component": "Identity.Backend",
                "environment": "production"
            ])
            throw Abort(
                .internalServerError,
                reason: "IDENTITIES_ENCRYPTION_KEY environment variable is required in production"
            )
        }

        if !hasEncryptionKey {
            logger.warning("Running without encryption - IDENTITIES_ENCRYPTION_KEY not set", metadata: [
                "component": "Identity.Backend",
                "environment": "\(application.environment)",
                "security": "⚠️ TOTP secrets and OAuth tokens will be stored unencrypted"
            ])
        }

        // Run Identity-specific migrations if requested
        if runMigrations {
            logger.trace("Running Identity database migrations")

            let migrator = Identity.Backend.migrator()
            try await migrator.migrate(database)

            logger.trace("Identity database migrations complete")
        }

        logger.trace("Identity database initialized")
        
        // Note: Backend doesn't add any middleware here as it's purely API-based
        // The consuming application should add appropriate API authentication middleware
        // based on their specific requirements (JWT, API keys, etc.)
        
        logger.debug("Identity Backend configured")
    }
}
