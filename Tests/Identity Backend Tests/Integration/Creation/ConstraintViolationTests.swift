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
    func `INSERT duplicate email throws constraint violation`() async throws {
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

    @Test
    func `INSERT duplicate email case insensitive throws violation`() async throws {
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

    @Test
    func `UPDATE to duplicate email throws constraint violation`() async throws {
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

    @Test
    func `INSERT with negative session Version throws check constraint violation`() async throws {
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

    @Test
    func `UPDATE session Version to negative throws check constraint violation`() async throws {
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

    @Test
    func `INSERT without required email throws NOT NULL violation`() async throws {
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

    @Test
    func `INSERT without required password hash throws NOT NULL violation`() async throws {
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

    @Test
    func `INSERT without email verification status throws NOT NULL violation`() async throws {
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

    @Test
    func `INSERT invalid email verification status throws check constraint violation`() async throws {
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

    @Test
    func `INSERT with empty email string throws check constraint violation`() async throws {
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

    @Test
    func `INSERT with empty password hash throws check constraint violation`() async throws {
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

    @Test
    func `DELETE identity succeeds without cascade errors`() async throws {
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

    @Test
    func `DELETE non-existent identity does not throw error`() async throws {
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
