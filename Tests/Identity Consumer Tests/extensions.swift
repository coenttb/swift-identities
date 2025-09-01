//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 03/03/2025.
//

import Identity_Consumer
import Identity_Shared
import ServerFoundationVapor_Testing
import DependenciesTestSupport
import EmailAddress
import Foundation
import JWT
import Testing
import Vapor
import VaporTesting

private func withTestConsumerApp(_ test: (Application) async throws -> Void) async throws {
    // Create a unique identifier for this test run
    let testId = UUID().uuidString.prefix(8).lowercased()
    print("🔵 Consumer Test starting with ID: \(testId)")

    let app = try await Application.make(.testing)

    try await withDependencies {
        $0.application = app
    } operation: {
        @Dependency(\.application) var application

        do {
            // Set up JWT for token handling
            let key = ES256PrivateKey()
            await application.jwt.keys.add(ecdsa: key)

            // Add necessary middleware
            app.middleware.use(Identity.Consumer.Middleware())

            // Set up routes
            @Dependency(\.identity.consumer.router) var router
            application.mount(router, use: Identity.Consumer.Route.response)

            print("🔵 Running consumer test with ID: \(testId)")
            try await test(app)
            print("🔵 Consumer test completed: \(testId)")
        } catch {
            print("🔴 Consumer test failed: \(testId) - Error: \(error)")
            try await application.asyncShutdown()
            throw error
        }

        print("🔵 Consumer test cleanup: \(testId)")
        try await app.asyncShutdown()
    }
}

extension TestingHTTPRequest {
    init(
        _ route: Identity.API
    ) throws {
        @Dependency(\.identity.provider.router) var router

        let urlRequestData = try router.print(route)
        try self.init(urlRequestData)
    }
}

extension Application {
    package func test(identity route: Identity.API) async throws -> TestingHTTPResponse {
        try await self.testing().performTest(request: .init(route))
    }
}
