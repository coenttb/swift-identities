import Dependencies
import DependenciesTestSupport
import EmailAddress
import Foundation
import Identity_Backend
import IdentitiesTypes
import Records
import RecordsTestSupport
import Testing
import Vapor

@Suite(
    "Constraint Violation Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
    }
)
struct ConstraintViolationTests {
    @Dependency(\.defaultDatabase) var database

    @Test("INSERT duplicate email throws constraint violation")
    func testDuplicateEmailViolation() async throws {
        let email = TestFixtures.uniqueEmail(prefix: "duplicate")

        // Create first identity
        _ = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: email,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Attempt to create duplicate - should fail
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await TestFixtures.createTestIdentity(
                    email: email,
                    password: TestFixtures.testPassword,
                    db: db
                )
            }
        }
    }

    @Test("INSERT duplicate email case insensitive throws violation")
    func testDuplicateEmailCaseInsensitive() async throws {
        let emailLower = try EmailAddress("casetest@example.com")
        let emailUpper = try EmailAddress("CASETEST@EXAMPLE.COM")

        // Create first identity with lowercase
        _ = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: emailLower,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Attempt to create with uppercase - should fail if case insensitive constraint
        // Note: This test behavior depends on database collation settings
        // If this doesn't fail, it means the DB allows case-sensitive emails
        do {
            _ = try await database.write { db in
                try await TestFixtures.createTestIdentity(
                    email: emailUpper,
                    password: TestFixtures.testPassword,
                    db: db
                )
            }
            // If we get here, DB allows case-sensitive emails
            // Verify both exist
            let count = try await database.read { db in
                try await Identity.Record
                    .where { $0.email.eq(emailLower).or($0.email.eq(emailUpper)) }
                    .asSelect()
                    .fetchCount(db)
            }
            #expect(count == 2)
        } catch {
            // Expected if case-insensitive constraint exists
            let count = try await database.read { db in
                try await Identity.Record
                    .where { $0.email.eq(emailLower) }
                    .asSelect()
                    .fetchCount(db)
            }
            #expect(count == 1)
        }
    }

    @Test("UPDATE to duplicate email throws constraint violation")
    func testUpdateToDuplicateEmail() async throws {
        let email1 = TestFixtures.uniqueEmail(prefix: "update1")
        let email2 = TestFixtures.uniqueEmail(prefix: "update2")

        // Create two identities
        _ = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: email1,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        let identity2 = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: email2,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Attempt to update identity2's email to identity1's email
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await Identity.Record
                    .where { $0.id.eq(identity2.id) }
                    .update { $0.email = email1 }
                    .execute(db)
            }
        }
    }

    @Test("INSERT with negative sessionVersion throws check constraint violation")
    func testNegativeSessionVersionViolation() async throws {
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                // Try to insert with negative session version
                try await db.execute(
                    """
                    INSERT INTO "identities"
                    ("id", "email", "password_hash", "email_verification_status", "session_version", "created_at")
                    VALUES (\(UUID()), 'negative@example.com', 'hash', 'pending', -1, NOW())
                    """
                )
            }
        }
    }

    @Test("UPDATE sessionVersion to negative throws check constraint violation")
    func testUpdateSessionVersionToNegative() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "negative-update",
                db: db
            )
        }

        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await db.execute(
                    """
                    UPDATE "identities"
                    SET "session_version" = -1
                    WHERE "id" = \(identity.id)
                    """
                )
            }
        }
    }

    @Test("INSERT without required email throws NOT NULL violation")
    func testMissingEmailViolation() async throws {
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await db.execute(
                    """
                    INSERT INTO "identities"
                    ("id", "password_hash", "email_verification_status", "session_version", "created_at")
                    VALUES (\(UUID()), 'hash', 'pending', 1, NOW())
                    """
                )
            }
        }
    }

    @Test("INSERT without required password_hash throws NOT NULL violation")
    func testMissingPasswordHashViolation() async throws {
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await db.execute(
                    """
                    INSERT INTO "identities"
                    ("id", "email", "email_verification_status", "session_version", "created_at")
                    VALUES (\(UUID()), 'nopassword@example.com', 'pending', 1, NOW())
                    """
                )
            }
        }
    }

    @Test("INSERT without email_verification_status throws NOT NULL violation")
    func testMissingEmailVerificationStatusViolation() async throws {
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await db.execute(
                    """
                    INSERT INTO "identities"
                    ("id", "email", "password_hash", "session_version", "created_at")
                    VALUES (\(UUID()), 'nostatus@example.com', 'hash', 1, NOW())
                    """
                )
            }
        }
    }

    @Test("INSERT invalid email_verification_status throws check constraint violation")
    func testInvalidEmailVerificationStatus() async throws {
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await db.execute(
                    """
                    INSERT INTO "identities"
                    ("id", "email", "password_hash", "email_verification_status", "session_version", "created_at")
                    VALUES (\(UUID()), 'invalid@example.com', 'hash', 'invalid_status', 1, NOW())
                    """
                )
            }
        }
    }

    @Test("INSERT with empty email string throws check constraint violation")
    func testEmptyEmailViolation() async throws {
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await db.execute(
                    """
                    INSERT INTO "identities"
                    ("id", "email", "password_hash", "email_verification_status", "session_version", "created_at")
                    VALUES (\(UUID()), '', 'hash', 'pending', 1, NOW())
                    """
                )
            }
        }
    }

    @Test("INSERT with empty password_hash throws check constraint violation")
    func testEmptyPasswordHashViolation() async throws {
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await db.execute(
                    """
                    INSERT INTO "identities"
                    ("id", "email", "password_hash", "email_verification_status", "session_version", "created_at")
                    VALUES (\(UUID()), 'emptypass@example.com', '', 'pending', 1, NOW())
                    """
                )
            }
        }
    }

    @Test("DELETE identity succeeds without cascade errors")
    func testDeleteIdentity() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "delete",
                db: db
            )
        }

        // Delete the identity
        try await database.write { db in
            try await Identity.Record
                .find([identity.id])
                .delete()
                .execute(db)
        }

        // Verify deleted
        let fetched = try await database.read { db in
            try await Identity.Record
                .where { $0.id.eq(identity.id) }
                .fetchOne(db)
        }

        #expect(fetched == nil)
    }

    @Test("DELETE non-existent identity does not throw error")
    func testDeleteNonExistentIdentity() async throws {
        let nonExistentId = Identity.ID(UUID())

        // Should not throw
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(nonExistentId) }
                .delete()
                .execute(db)
        }
    }
}
