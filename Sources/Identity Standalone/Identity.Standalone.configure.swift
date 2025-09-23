//
//  Identity.Standalone.configure.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Records
import Identity_Backend
import Dependencies
import Logging
import Vapor

extension Identity.Standalone {
    /// Configures a Vapor application for standalone Identity deployment.
    ///
    /// This function sets up authentication middleware for Identity.
    /// The database should already be configured by the application before calling this.
    /// Migrations can be run separately using Identity.Database.migrate().
    ///
    /// - Parameters:
    ///   - application: The Vapor application to configure
    ///   - runMigrations: Whether to run Identity database migrations (default: true)
    /// - Throws: Any errors during configuration
    public static func configure(
        _ application: Vapor.Application,
        runMigrations: Bool = true
    ) async throws {
        @Dependency(\.logger) var logger
        @Dependency(\.defaultDatabase) var database
        
        logger.trace("Configuring Identity Standalone")
        
        try await Identity.Backend.configure(
            application,
            runMigrations: runMigrations
        )
        
        @Dependency(Identity.Standalone.Configuration.self) var configuration
        @Dependency(\.identity.oauth?.client.registerProvider) var registerProvider

        if
            let registerProvider,
            let providers = configuration.oauth?.providers {
            for provider in providers {
                do {
                    try await registerProvider(provider)
                } catch {
                    logger.warning("\(provider.displayName) identity provider not registered")
                }
            }
        }
        
        application.middleware.use(Identity.Standalone.Authenticator())
        
        logger.trace("Identity authenticator middleware registered")
        
        logger.debug("Identity Standalone configured")
    }
}
