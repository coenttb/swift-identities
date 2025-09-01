//
//  JWTTokenTests.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 28/02/2025.
//

import Identity_Provider
import Identity_Shared
import DependenciesTestSupport
import EmailAddress
import FluentSQLiteDriver
import Foundation
import JWT
import Testing
import Vapor
import VaporTesting

// TODO: Update these tests to work with the new swift-jwt based Identity.Token implementation
// The old JWTKit-based Identity.Token.Access has been replaced with Identity.Token.Access

@Suite(
    "JWT Token Tests",
    .dependency(\.date, .init(Date.init))
)
struct JWTTokenTests {
    @Test("JWT Token Access should encode both identity ID and email in subject")
    func testAccessTokenSubjectFormat() async throws {
        // Create test identity ID and email address
        let testIdentityId = UUID()
        let testEmail = try EmailAddress("test@example.com")

        @Dependency(\.date) var date
        // Create a JWT Access token directly
        let accessToken = Identity.Token.Access(
            expiration: .init(value: date().addingTimeInterval(3600)),
            issuedAt: .init(value: date()),
            identityId: testIdentityId,
            email: testEmail
        )

        // Check that subject contains both ID and email in correct format
        let subjectComponents = accessToken.subject.value.components(separatedBy: ":")
        #expect(subjectComponents.count == 2, "Subject should contain both ID and email separated by ':'")
        #expect(subjectComponents[0] == testIdentityId.uuidString, "First part of subject should be identity ID")
        #expect(subjectComponents[1] == testEmail.rawValue, "Second part of subject should be email")

        // Verify accessors work correctly
        #expect(accessToken.identityId == testIdentityId, "identityId accessor should return correct ID")
        #expect(accessToken.emailAddress == testEmail, "email accessor should return correct email")

        // Test the setters also work correctly
        let newIdentityId = UUID()
        let newEmail = try EmailAddress("new@example.com")

        var mutableToken = accessToken
        mutableToken.identityId = newIdentityId
        mutableToken.emailAddress = newEmail

        #expect(mutableToken.identityId == newIdentityId, "identityId setter should update correctly")
        #expect(mutableToken.emailAddress == newEmail, "email setter should update correctly")

        // Verify the subject was updated with both values
        let updatedComponents = mutableToken.subject.value.components(separatedBy: ":")
        #expect(updatedComponents.count == 2, "Updated subject should maintain format")
        #expect(updatedComponents[0] == newIdentityId.uuidString, "First part should be updated ID")
        #expect(updatedComponents[1] == newEmail.rawValue, "Second part should be updated email")
    }

    @Test("JWT token encoding and decoding should preserve subject format with email")
    func testTokenEncodingDecoding() async throws {
        try await withTestApp { app in
            // 1. Create an access token with identity ID and email
            let identityId = UUID()
            let email = try EmailAddress("encode-test@example.com")

            @Dependency(\.date) var date

            let accessToken = Identity.Token.Access(
                expiration: .init(value: date().addingTimeInterval(3600)),
                issuedAt: .init(value: date()),
                identityId: identityId,
                email: email
            )

            // 2. Encode the token to a string
            let encodedToken = try await app.jwt.keys.sign(accessToken)

            // 3. Decode the token back
            let decodedToken = try await app.jwt.keys.verify(encodedToken, as: Identity.Token.Access.self)

            // 4. Verify the subject format is preserved
            let components = decodedToken.subject.value.components(separatedBy: ":")
            #expect(components.count == 2, "Subject should contain both ID and email separated by ':' after decode")
            #expect(components[0] == identityId.uuidString, "First part should be identity ID after decode")
            #expect(components[1] == email.rawValue, "Second part should be email after decode")

            // 5. Verify accessors work on decoded token
            #expect(decodedToken.identityId == identityId, "identityId should be preserved")
            #expect(decodedToken.emailAddress == email, "emailAddress should be preserved")
        }
    }

    @Test("JWT token should correctly verify expiration")
    func testTokenExpiration() async throws {
        try await withTestApp { app in
            @Dependency(\.date) var date
            let identityId = UUID()
            let email = try EmailAddress("expired-test@example.com")
            let pastTime = date().addingTimeInterval(-3600) // 1 hour ago

            let expiredToken = Identity.Token.Access(
                expiration: .init(value: pastTime),
                issuedAt: .init(value: pastTime.addingTimeInterval(-10)), // Issued 10 seconds before expiration
                identityId: identityId,
                email: email
            )

            // Sign the token
            let signedExpiredToken = try await app.jwt.keys.sign(expiredToken)

            // Verification should fail with expired error
            do {
                _ = try await app.jwt.keys.verify(signedExpiredToken, as: Identity.Token.Access.self)
                #expect(Bool(false), "Verification should have failed with expired token")
            } catch let error as JWTError {
                // Expect JWTError.expired or similar error
                #expect(Bool(true), "Correctly caught JWT expiration error: \(error)")
            }
        }
    }
}
