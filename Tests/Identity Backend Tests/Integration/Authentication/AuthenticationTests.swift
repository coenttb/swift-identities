import Dependencies
import Dependencies_Test_Support
import EmailAddress
import Foundation
import IdentitiesTypes
import Identity_Backend
import Records
import RecordsTestSupport
import Testing
import Vapor

@Suite(

    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
    }
)
struct Test {
    @Dependency(\.defaultDatabase) var database

    @Test
    func `INSERT identity with password returns complete record`() async throws {
        // Arrange & Act: Create test user
        let identity = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: TestFixtures.testEmail,
                password: TestFixtures.testPassword,
                verified: true,
                db: db
            )
        }

        // Assert
        #expect(identity.email == TestFixtures.testEmail)
        #expect(identity.emailVerificationStatus == .verified)
        #expect(!identity.passwordHash.isEmpty)
    }

    @Test
    func `Bcrypt.verify succeeds with correct password`() async throws {
        // Arrange: Create test user
        let identity = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: TestFixtures.testEmail,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Act & Assert: Verify correct password
        let isValid = try Bcrypt.verify(
            TestFixtures.testPassword,
            created: identity.passwordHash
        )
        #expect(isValid == true)
    }

    @Test
    func `Bcrypt.verify fails with incorrect password`() async throws {
        // Arrange: Create test user
        let identity = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: TestFixtures.testEmail,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Act & Assert: Try with wrong password
        let isValid = try Bcrypt.verify(
            "WrongPassword123!",
            created: identity.passwordHash
        )
        #expect(isValid == false)
    }

    @Test
    func `SELECT identity by email returns matching record`() async throws {
        // Arrange: Create test user
        _ = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: TestFixtures.testEmail,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Act: Find by email
        let foundIdentity = try await database.read { db in
            try await Identity.Record
                .where { $0.email.eq(TestFixtures.testEmail) }
                .fetchOne(db)
        }

        // Assert
        let identity = try #require(foundIdentity)
        #expect(identity.email == TestFixtures.testEmail)
    }

    @Test
    func `UPDATE last Login At timestamp persists to database`() async throws {
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
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Act: Update last login
        let newLoginTime = Date()
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(createdIdentity.id) }
                .update { $0.lastLoginAt = newLoginTime }
                .execute(db)
        }

        // Assert: Last login was updated
        let updatedIdentity = try #require(
            try await database.read { db in
                try await Identity.Record
                    .where { $0.email.eq(TestFixtures.testEmail) }
                    .fetchOne(db)
            }
        )

        if let originalLastLogin {
            #expect(updatedIdentity.lastLoginAt! > originalLastLogin)
        } else {
            #expect(updatedIdentity.lastLoginAt != nil)
        }
    }

    @Test
    func `UPDATE session Version increments correctly`() async throws {
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
        let updatedIdentity = try #require(
            try await database.read { db in
                try await Identity.Record
                    .where { $0.id.eq(initialIdentity.id) }
                    .fetchOne(db)
            }
        )

        #expect(updatedIdentity.sessionVersion == initialSessionVersion + 1)
    }
}
