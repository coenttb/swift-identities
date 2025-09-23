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
        
        logger.trace("Configuring Identity Backend")
        
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
