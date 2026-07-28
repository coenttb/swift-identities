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

    // MARK: - UPDATE Operations

    @Test
    func `UPDATE email changes identity email`() async throws {
        let oldEmail = TestFixtures.uniqueEmail(prefix: "old")
        let newEmail = TestFixtures.uniqueEmail(prefix: "new")

        let identity = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: oldEmail,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Update email
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(identity.id) }
                .update { $0.email = newEmail }
                .execute(db)
        }

        // Verify updated
        let fetched = try #require(
            try await database.read { db in
                try await Identity.Record
                    .where { $0.id.eq(identity.id) }
                    .fetchOne(db)
            }
        )

        #expect(fetched.email == newEmail)
    }

    @Test
    func `UPDATE password hash changes hashed password`() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "password-update",
                db: db
            )
        }

        let oldHash = identity.passwordHash
        let newPassword = "NewPassword456!"
        let newHash = try Bcrypt.hash(newPassword)

        // Update password hash
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(identity.id) }
                .update { $0.passwordHash = newHash }
                .execute(db)
        }

        // Verify updated
        let fetched = try #require(
            try await database.read { db in
                try await Identity.Record
                    .where { $0.id.eq(identity.id) }
                    .fetchOne(db)
            }
        )

        #expect(fetched.passwordHash != oldHash)
        #expect(try Bcrypt.verify(newPassword, created: fetched.passwordHash))
    }

    @Test
    func `UPDATE email Verification Status changes verification status`() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: TestFixtures.uniqueEmail(prefix: "verify"),
                password: TestFixtures.testPassword,
                verified: false,
                db: db
            )
        }

        #expect(identity.emailVerificationStatus == .pending)

        // Update to verified
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(identity.id) }
                .update { $0.emailVerificationStatus = .verified }
                .execute(db)
        }

        // Verify updated
        let fetched = try #require(
            try await database.read { db in
                try await Identity.Record
                    .where { $0.id.eq(identity.id) }
                    .fetchOne(db)
            }
        )

        #expect(fetched.emailVerificationStatus == Identity.Record.EmailVerificationStatus.verified)
    }

    @Test
    func `UPDATE multiple fields in single operation`() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "multi-update",
                verified: false,
                db: db
            )
        }

        let newEmail = TestFixtures.uniqueEmail(prefix: "updated")

        // Update multiple fields
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(identity.id) }
                .update { record in
                    record.email = newEmail
                    record.emailVerificationStatus = .verified
                    record.sessionVersion += 1
                }
                .execute(db)
        }

        // Verify all updated
        let fetched = try #require(
            try await database.read { db in
                try await Identity.Record
                    .where { $0.id.eq(identity.id) }
                    .fetchOne(db)
            }
        )

        #expect(fetched.email == newEmail)
        #expect(fetched.emailVerificationStatus == Identity.Record.EmailVerificationStatus.verified)
        #expect(fetched.sessionVersion == identity.sessionVersion + 1)
    }

    @Test
    func `UPDATE non-existent identity affects zero rows`() async throws {
        let nonExistentId = Identity.ID(UUID())

        // Should not throw, but affects 0 rows
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(nonExistentId) }
                .update { $0.sessionVersion = 999 }
                .execute(db)
        }

        // Verify identity doesn't exist
        let fetched = try await database.read { db in
            try await Identity.Record
                .where { $0.id.eq(nonExistentId) }
                .fetchOne(db)
        }

        #expect(fetched == nil)
    }

    // MARK: - DELETE Operations

    @Test
    func `DELETE single identity removes from database`() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "delete",
                db: db
            )
        }

        // Delete
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(identity.id) }
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
    func `DELETE multiple identities by IDs`() async throws {
        // Create 3 identities
        var ids: [Identity.ID] = []
        for i in 0..<3 {
            let identity = try await database.write { db in
                try await TestFixtures.createTestIdentity(
                    email: try EmailAddress("delete\(i)@example.com"),
                    password: TestFixtures.testPassword,
                    db: db
                )
            }
            ids.append(identity.id)
        }

        let idsToDelete = ids  // Capture as immutable
        // Delete all 3
        try await database.write { db in
            try await Identity.Record
                .where { idsToDelete.contains($0.id) }
                .delete()
                .execute(db)
        }

        // Verify all deleted
        let count = try await database.read { db in
            try await Identity.Record
                .where { idsToDelete.contains($0.id) }
                .asSelect()
                .fetchCount(db)
        }

        #expect(count == 0)
    }

    @Test
    func `DELETE with WHERE clause`() async throws {
        let targetEmail = TestFixtures.uniqueEmail(prefix: "target")

        // Create target identity
        _ = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: targetEmail,
                password: TestFixtures.testPassword,
                verified: false,
                db: db
            )
        }

        // Create other identities that shouldn't be deleted
        _ = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "keep",
                verified: true,
                db: db
            )
        }

        // Delete only unverified
        try await database.write { db in
            try await Identity.Record
                .where {
                    $0.emailVerificationStatus.eq(Identity.Record.EmailVerificationStatus.pending)
                }
                .delete()
                .execute(db)
        }

        // Verify target deleted
        let targetFetched = try await database.read { db in
            try await Identity.Record
                .where { $0.email.eq(targetEmail) }
                .fetchOne(db)
        }
        #expect(targetFetched == nil)

        // Verify verified identity still exists
        let verifiedCount = try await database.read { db in
            try await Identity.Record
                .where {
                    $0.emailVerificationStatus.eq(Identity.Record.EmailVerificationStatus.verified)
                }
                .asSelect()
                .fetchCount(db)
        }
        #expect(verifiedCount > 0)
    }

    // MARK: - SELECT Operations

    @Test
    func `SELECT with WHERE filters correctly`() async throws {
        let targetEmail = TestFixtures.uniqueEmail(prefix: "select-where")

        // Create identities
        _ = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: targetEmail,
                password: TestFixtures.testPassword,
                verified: true,
                db: db
            )
        }

        _ = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "other",
                verified: false,
                db: db
            )
        }

        // Select only verified
        let verified = try await database.read { db in
            try await Identity.Record
                .where {
                    $0.emailVerificationStatus.eq(Identity.Record.EmailVerificationStatus.verified)
                }
                .fetchAll(db)
        }

        #expect(verified.contains { $0.email == targetEmail })
        #expect(
            verified.allSatisfy {
                $0.emailVerificationStatus == Identity.Record.EmailVerificationStatus.verified
            }
        )
    }

    @Test
    func `SELECT fetch All returns all records`() async throws {
        let countBefore = try await database.read { db in
            try await Identity.Record.fetchAll(db).count
        }

        // Create 3 identities
        for i in 0..<3 {
            _ = try await database.write { db in
                try await TestFixtures.createTestIdentity(
                    email: try EmailAddress("fetchall\(i)@example.com"),
                    password: TestFixtures.testPassword,
                    db: db
                )
            }
        }

        let countAfter = try await database.read { db in
            try await Identity.Record.fetchAll(db).count
        }

        #expect(countAfter == countBefore + 3)
    }

    @Test
    func `SELECT fetch Count returns correct count`() async throws {
        let countBefore = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        // Create identity
        _ = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "count",
                db: db
            )
        }

        let countAfter = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        #expect(countAfter == countBefore + 1)
    }

    @Test
    func `SELECT with complex WHERE conditions`() async throws {
        let email1 = TestFixtures.uniqueEmail(prefix: "complex1")
        let email2 = TestFixtures.uniqueEmail(prefix: "complex2")

        // Create verified identity
        let identity1 = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: email1,
                password: TestFixtures.testPassword,
                verified: true,
                db: db
            )
        }

        // Create unverified identity
        _ = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: email2,
                password: TestFixtures.testPassword,
                verified: false,
                db: db
            )
        }

        // Select verified OR specific email
        let results = try await database.read { db in
            try await Identity.Record
                .where {
                    $0.emailVerificationStatus.eq(Identity.Record.EmailVerificationStatus.verified)
                        .or($0.email.eq(email2))
                }
                .fetchAll(db)
        }

        #expect(results.count >= 2)
        #expect(results.contains { $0.id == identity1.id })
        #expect(results.contains { $0.email == email2 })
    }

    // MARK: - Batch Operations

    @Test
    func `Batch INSERT multiple identities`() async throws {
        var emails: [EmailAddress] = []
        for i in 0..<5 {
            emails.append(try EmailAddress("batch\(i)@example.com"))
        }

        // Insert all in sequence (Records doesn't have built-in batch insert)
        for email in emails {
            _ = try await database.write { db in
                try await TestFixtures.createTestIdentity(
                    email: email,
                    password: TestFixtures.testPassword,
                    db: db
                )
            }
        }

        let emailList = emails  // Capture as immutable
        // Verify all created
        let count = try await database.read { db in
            try await Identity.Record
                .where { emailList.contains($0.email) }
                .asSelect()
                .fetchCount(db)
        }

        #expect(count == 5)
    }

    @Test
    func `Batch UPDATE multiple identities`() async throws {
        // Create identities
        var ids: [Identity.ID] = []
        for i in 0..<3 {
            let identity = try await database.write { db in
                try await TestFixtures.createTestIdentity(
                    email: try EmailAddress("batchupdate\(i)@example.com"),
                    password: TestFixtures.testPassword,
                    verified: false,
                    db: db
                )
            }
            ids.append(identity.id)
        }

        let idsToUpdate = ids  // Capture as immutable

        // Batch update all to verified
        try await database.write { db in
            try await Identity.Record
                .where { idsToUpdate.contains($0.id) }
                .update { $0.emailVerificationStatus = .verified }
                .execute(db)
        }

        // Verify all updated
        let verifiedCount = try await database.read { db in
            try await Identity.Record
                .where {
                    idsToUpdate.contains($0.id)
                        .and(
                            $0.emailVerificationStatus.eq(
                                Identity.Record.EmailVerificationStatus.verified
                            )
                        )
                }
                .asSelect()
                .fetchCount(db)
        }

        #expect(verifiedCount == 3)
    }
}
