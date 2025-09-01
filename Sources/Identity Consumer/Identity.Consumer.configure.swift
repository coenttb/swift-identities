//
//  Identity.Consumer.configure.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Boiler
import Dependencies
import Logging
import Vapor

extension Identity.Consumer {
    /// Configures a Vapor application as an Identity consumer.
    ///
    /// This function sets up everything needed for a consumer that connects to a remote Identity provider:
    /// - Authentication middleware for token and credential validation
    /// - No database setup (consumer connects to provider)
    ///
    /// - Parameter application: The Vapor application to configure
    public static func configure(_ application: Vapor.Application) async throws {
        @Dependency(\.logger) var logger
        
        logger.info("Configuring Identity Consumer", metadata: [
            "component": "Identity.Consumer",
            "operation": "configure"
        ])
        
        // Register consumer middleware for authentication
        application.middleware.use(Identity.Consumer.Middleware())
        
        logger.debug("Identity consumer middleware registered", metadata: [
            "component": "Identity.Consumer",
            "operation": "middleware.registered"
        ])
        
        logger.info("Identity Consumer configuration complete", metadata: [
            "component": "Identity.Consumer",
            "operation": "configure.success"
        ])
    }
}