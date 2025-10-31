import Dependencies
import DependenciesTestSupport
import EmailAddress
import Foundation
import Identity_Backend
import IdentitiesTypes
import Records
import RecordsTestSupport
import Testing

@Suite("Authentication Tests")
struct AuthenticationTests {
    @Test("Authenticate with valid credentials")
    func testValidCredentialsAuthentication() async throws {
        try await withDependencies {
            $0.defaultDatabase = try await Database.withIdentitySchema()
        } operation: {
            @Dependency(\.defaultDatabase) var database
            @Dependency(\.identity.backend) var backend

            // Arrange: Create test user
            try await database.write { db in
                _ = try await TestFixtures.createTestIdentity(
                    email: TestFixtures.testEmail,
                    password: TestFixtures.testPassword,
                    verified: true,
                    db: db
                )
            }

            // Act: Authenticate
            let credentials = Identity.Authentication.Credentials(
                email: TestFixtures.testEmail,
                password: TestFixtures.testPassword
            )

            let response = try await backend.authenticate.credentials(credentials)

            // Assert
            #expect(response.accessToken != "")
            #expect(response.refreshToken != "")
        }
    }

    @Test("Reject invalid password")
    func testInvalidPasswordRejection() async throws {
        try await withDependencies {
            $0.defaultDatabase = try await Database.withIdentitySchema()
        } operation: {
            @Dependency(\.defaultDatabase) var database
            @Dependency(\.identity.backend) var backend

            // Arrange: Create test user
            try await database.write { db in
                _ = try await TestFixtures.createTestIdentity(
                    email: TestFixtures.testEmail,
                    password: TestFixtures.testPassword,
                    db: db
                )
            }

            // Act & Assert: Try with wrong password
            let credentials = Identity.Authentication.Credentials(
                email: TestFixtures.testEmail,
                password: "WrongPassword123!"
            )

            #expect(throws: Error.self) {
                try await backend.authenticate.credentials(credentials)
            }
        }
    }

    @Test("Reject non-existent user")
    func testNonExistentUserRejection() async throws {
        try await withDependencies {
            $0.defaultDatabase = try await Database.withIdentitySchema()
        } operation: {
            @Dependency(\.identity.backend) var backend

            // Act & Assert: Try to authenticate non-existent user
            let credentials = Identity.Authentication.Credentials(
                email: try EmailAddress("nonexistent@example.com"),
                password: "Password123!"
            )

            #expect(throws: Error.self) {
                try await backend.authenticate.credentials(credentials)
            }
        }
    }

    @Test("Update last login timestamp")
    func testLastLoginTimestampUpdate() async throws {
        try await withDependencies {
            $0.defaultDatabase = try await Database.withIdentitySchema()
        } operation: {
            @Dependency(\.defaultDatabase) var database
            @Dependency(\.identity.backend) var backend

            // Arrange: Create test user
            let createdIdentity = try await database.write { db in
                try await TestFixtures.createTestIdentity(
                    email: TestFixtures.testEmail,
                    password: TestFixtures.testPassword,
                    db: db
                )
            }

            let originalLastLogin = createdIdentity.lastLoginAt

            // Wait a moment to ensure timestamp difference
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Act: Authenticate
            let credentials = Identity.Authentication.Credentials(
                email: TestFixtures.testEmail,
                password: TestFixtures.testPassword
            )

            _ = try await backend.authenticate.credentials(credentials)

            // Assert: Last login was updated
            let updatedIdentity = try await database.read { db in
                try await Identity.Record
                    .where { $0.email.eq(TestFixtures.testEmail) }
                    .fetchOne(db)!
            }

            if let originalLastLogin {
                #expect(updatedIdentity.lastLoginAt! > originalLastLogin)
            } else {
                #expect(updatedIdentity.lastLoginAt != nil)
            }
        }
    }

    @Test("Session version increments correctly")
    func testSessionVersionIncrement() async throws {
        try await withDependencies {
            $0.defaultDatabase = try await Database.withIdentitySchema()
        } operation: {
            @Dependency(\.defaultDatabase) var database

            // Arrange: Create test user
            let initialIdentity = try await database.write { db in
                try await TestFixtures.createTestIdentity(
                    email: TestFixtures.testEmail,
                    password: TestFixtures.testPassword,
                    db: db
                )
            }

            let initialSessionVersion = initialIdentity.sessionVersion

            // Act: Increment session version (simulating password change)
            try await database.write { db in
                try await Identity.Record
                    .where { $0.id.eq(initialIdentity.id) }
                    .update { record in
                        record.sessionVersion = record.sessionVersion + 1
                    }
                    .execute(db)
            }

            // Assert: Session version incremented
            let updatedIdentity = try await database.read { db in
                try await Identity.Record
                    .where { $0.id.eq(initialIdentity.id) }
                    .fetchOne(db)!
            }

            #expect(updatedIdentity.sessionVersion == initialSessionVersion + 1)
        }
    }
}
