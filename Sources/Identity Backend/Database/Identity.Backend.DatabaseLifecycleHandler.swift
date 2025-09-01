//
//  Identity.Backend.DatabaseLifecycleHandler.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Boiler
import Records
import Dependencies
import Logging

extension Identity.Backend {
    /// Handles database lifecycle management for Identity services.
    /// Automatically closes the database connection when the application shuts down.
    package struct DatabaseLifecycleHandler: LifecycleHandler {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.logger) var logger
        
        package init() {
            
        }
        
        package func shutdown(_ application: Application) {
            application.eventLoopGroup.next().execute {
                Task {
                    do {
                        try await database.close()
                        logger.info("Identity database connection closed successfully", metadata: [
                            "component": "Identity.Backend",
                            "operation": "shutdown"
                        ])
                    } catch {
                        logger.error("Failed to close Identity database connection", metadata: [
                            "component": "Identity.Backend",
                            "operation": "shutdown",
                            "error": "\(error)"
                        ])
                    }
                }
            }
        }
    }
}
