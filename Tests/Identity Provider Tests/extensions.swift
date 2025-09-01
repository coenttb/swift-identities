//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 28/02/2025.
//

import Identity_Provider
import ServerFoundationVapor_Testing
import Dependencies
import EmailAddress
import Fluent
import Foundation
import JWT
import Testing
import URLRouting
import Vapor
import VaporTesting

func withTestApp(_ test: (Application) async throws -> Void) async throws {

    // Create a unique database ID for this test run to prevent cross-test contamination
    let dbId = UUID().uuidString
    let testId = dbId.prefix(8)
    print("🔵 Test starting with ID: \(testId)")

    let app = try await Application.make(.testing)

    // Use a unique database ID for isolation between tests
    let db = DatabaseID(string: dbId)
    app.databases.use(.sqlite(.memory), as: db)
    app.migrations.add(Database.Migration())
    app.middleware.use(Identity.Provider.Middleware())

    try await app.autoMigrate()

    try await withDependencies {
        $0.identity.provider.rateLimiters = .init()
        $0.application = app
        $0.database = app.databases.database(db, logger: $0.logger, on: app.eventLoopGroup.next())!
    } operation: {
        @Dependency(\.application) var application

        do {
            let key = ES256PrivateKey()
            await application.jwt.keys.add(ecdsa: key)
            try await application.autoMigrate()

            @Dependency(\.identity.provider.router) var router

            application.mount(router, use: Identity.Provider.API.response)

            print("🔵 Running test with ID: \(testId)")
            try await test(app)
            print("🔵 Test completed: \(testId)")

            try await application.autoRevert()
        } catch {
            print("🔴 Test failed: \(testId) - Error: \(error)")
            try await application.asyncShutdown()
            throw error
        }

        print("🔵 Test cleanup: \(testId)")
        try await app.asyncShutdown()
    }
}

func setupMockIdentity(app: Application) async throws -> (email: String, password: String) {
    // Generate a unique test email for each test run
    let uniqueId = UUID().uuidString.prefix(8).lowercased()
    let testEmail = "test-\(uniqueId)@example.com"
    let testPassword = "securePassword123!"

    print("Creating mock identity with email: \(testEmail)")

    let createResponse = try await app.test(
        identity: .create(
            .request(
                .init(
                    email: testEmail,
                    password: testPassword
                )
            )
        )
    )

    #expect(createResponse.status == .ok, "Expected successful identity creation")

    let identity = try await Database.Identity.get(by: .email(try EmailAddress(testEmail)), on: app.db)

    #expect(identity.emailVerificationStatus == .unverified, "Expected email verification status to be pending")

    // Retrieve the verification token
    guard let tokenRecord = try await Database.Identity.Token.query(on: app.db)
        .filter(\.$identity.$id == identity.id!)
        .filter(\.$type == .emailVerification)
        .first()
    else { #expect(Bool(false)); fatalError() }

    let verificationToken = tokenRecord.value
    print("Verifying identity with token: \(verificationToken)")

    // Verify the email
    let verifyResponse = try await app.test(
        identity: .create(
            .verify(
                .init(
                    token: verificationToken,
                    email: testEmail
                )
            )
        )
    )

    // Verify the email verification was successful
    #expect(verifyResponse.status == .created, "Expected successful email verification")

    // Check database that email verification status is now verified
    let updatedIdentity = try await Database.Identity.get(by: .email(try EmailAddress(testEmail)), on: app.db)
    #expect(updatedIdentity.emailVerificationStatus == .verified, "Expected email verification status to be verified")

    print("Successfully created and verified mock identity: \(testEmail)")
    return (testEmail, testPassword) // Return the identity for use in tests
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

extension Identity.Provider.Client {
    static let liveTest: Self = .live(
        sendVerificationEmail: { _, _ in
            print("sendVerificationEmail called")
        },
        sendPasswordResetEmail: { _, _ in
            print("sendPasswordResetEmail called")
        },
        sendPasswordChangeNotification: { _ in
            print("sendPasswordChangeNotification called")
        },
        sendEmailChangeConfirmation: { _, _, _ in
            print("sendEmailChangeConfirmation called")
        },
        sendEmail.Change.RequestNotification: { _, _ in
            print("sendEmail.Change.RequestNotification called")
        },
        onEmailChangeSuccess: { _, _ in
            print("onEmailChangeSuccess called")
        },
        sendDeletionRequestNotification: { _ in
            print("sendDeletionRequestNotification called")
        },
        sendDeletionConfirmationNotification: { _ in
            print("sendDeletionConfirmationNotification called")
        }
    )
}
