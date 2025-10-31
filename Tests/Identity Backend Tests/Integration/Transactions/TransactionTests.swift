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
    "Transaction Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
    }
)
struct TransactionTests {
    @Dependency(\.defaultDatabase) var database

    enum TestError: Error {
        case intentionalRollback
    }

    @Test("Transaction COMMIT persists identity creation")
    func testTransactionCommit() async throws {
        let email = TestFixtures.uniqueEmail(prefix: "commit")

        let identityId = try await database.withTransaction { db in
            let identity = try await TestFixtures.createTestIdentity(
                email: email,
                password: TestFixtures.testPassword,
                db: db
            )
            return identity.id
        }

        // Verify committed
        let fetched = try await database.read { db in
            try await Identity.Record
                .where { $0.id.eq(identityId) }
                .fetchOne(db)
        }

        let identity = try #require(fetched)
        #expect(identity.email == email)
    }

    @Test("Transaction ROLLBACK on error does not persist changes")
    func testTransactionRollback() async throws {
        let countBefore = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        do {
            try await database.withTransaction { db in
                // Create identity
                _ = try await TestFixtures.createTestIdentity(
                    email: TestFixtures.uniqueEmail(prefix: "rollback"),
                    password: TestFixtures.testPassword,
                    db: db
                )

                // Force error to trigger rollback
                throw TestError.intentionalRollback
            }
            Issue.record("Transaction should have thrown error")
        } catch TestError.intentionalRollback {
            // Expected
        }

        let countAfter = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        #expect(countBefore == countAfter)
    }

    @Test("Transaction ROLLBACK on database error does not persist partial changes")
    func testTransactionRollbackOnDatabaseError() async throws {
        let email = TestFixtures.uniqueEmail(prefix: "dberror")
        let countBefore = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        do {
            try await database.withTransaction { db in
                // Create first identity successfully
                _ = try await TestFixtures.createTestIdentity(
                    email: email,
                    password: TestFixtures.testPassword,
                    db: db
                )

                // Try to create duplicate - will fail
                _ = try await TestFixtures.createTestIdentity(
                    email: email,
                    password: TestFixtures.testPassword,
                    db: db
                )
            }
            Issue.record("Transaction should have thrown database error")
        } catch {
            // Expected - duplicate key error
        }

        let countAfter = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        // No identities should have been created
        #expect(countBefore == countAfter)
    }

    @Test("Nested transaction with SAVEPOINT commits inner changes")
    func testSavepointCommit() async throws {
        let outerEmail = TestFixtures.uniqueEmail(prefix: "outer")
        let innerEmail = TestFixtures.uniqueEmail(prefix: "inner")

        try await database.withTransaction { db in
            // Create outer identity
            let outerIdentity = try await TestFixtures.createTestIdentity(
                email: outerEmail,
                password: TestFixtures.testPassword,
                db: db
            )

            // Create savepoint and inner identity
            try await db.withSavepoint(nil) { db in
                _ = try await TestFixtures.createTestIdentity(
                    email: innerEmail,
                    password: TestFixtures.testPassword,
                    db: db
                )
            }

            // Verify both exist within transaction
            let count = try await Identity.Record
                .where { $0.id.eq(outerIdentity.id).or($0.email.eq(innerEmail)) }
                .asSelect()
                .fetchCount(db)
            #expect(count == 2)
        }

        // Verify both committed
        let outerFetched = try await database.read { db in
            try await Identity.Record
                .where { $0.email.eq(outerEmail) }
                .fetchOne(db)
        }
        #expect(outerFetched != nil)

        let innerFetched = try await database.read { db in
            try await Identity.Record
                .where { $0.email.eq(innerEmail) }
                .fetchOne(db)
        }
        #expect(innerFetched != nil)
    }

    @Test("SAVEPOINT ROLLBACK reverts inner changes but keeps outer")
    func testSavepointRollback() async throws {
        let outerEmail = TestFixtures.uniqueEmail(prefix: "outer-rollback")
        let innerEmail = TestFixtures.uniqueEmail(prefix: "inner-rollback")

        try await database.withTransaction { db in
            // Create outer identity
            let outerIdentity = try await TestFixtures.createTestIdentity(
                email: outerEmail,
                password: TestFixtures.testPassword,
                db: db
            )

            do {
                try await db.withSavepoint(nil) { db in
                    _ = try await TestFixtures.createTestIdentity(
                        email: innerEmail,
                        password: TestFixtures.testPassword,
                        db: db
                    )
                    throw TestError.intentionalRollback
                }
            } catch TestError.intentionalRollback {
                // Expected - inner rolled back
            }

            // Verify outer still exists
            let fetched = try await Identity.Record
                .where { $0.id.eq(outerIdentity.id) }
                .fetchOne(db)
            #expect(fetched != nil)

            // Verify inner was rolled back
            let innerFetched = try await Identity.Record
                .where { $0.email.eq(innerEmail) }
                .fetchOne(db)
            #expect(innerFetched == nil)
        }

        // Verify outer committed
        let outerFetched = try await database.read { db in
            try await Identity.Record
                .where { $0.email.eq(outerEmail) }
                .fetchOne(db)
        }
        #expect(outerFetched != nil)

        // Verify inner not committed
        let innerFetched = try await database.read { db in
            try await Identity.Record
                .where { $0.email.eq(innerEmail) }
                .fetchOne(db)
        }
        #expect(innerFetched == nil)
    }

    @Test("Multiple sequential transactions are isolated")
    func testSequentialTransactionIsolation() async throws {
        let email1 = TestFixtures.uniqueEmail(prefix: "seq1")
        let email2 = TestFixtures.uniqueEmail(prefix: "seq2")

        // Transaction 1
        let id1 = try await database.withTransaction { db in
            let identity = try await TestFixtures.createTestIdentity(
                email: email1,
                password: TestFixtures.testPassword,
                db: db
            )
            return identity.id
        }

        // Transaction 2
        let id2 = try await database.withTransaction { db in
            let identity = try await TestFixtures.createTestIdentity(
                email: email2,
                password: TestFixtures.testPassword,
                db: db
            )
            return identity.id
        }

        // Verify both committed independently
        let count = try await database.read { db in
            try await Identity.Record
                .where { $0.id.eq(id1).or($0.id.eq(id2)) }
                .asSelect()
                .fetchCount(db)
        }

        #expect(count == 2)
    }

    @Test("Transaction with UPDATE and SELECT maintains consistency")
    func testTransactionWithUpdateAndSelect() async throws {
        let email = TestFixtures.uniqueEmail(prefix: "update-select")

        // Create identity
        let identity = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: email,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Update and verify within transaction
        try await database.withTransaction { db in
            // Update session version
            try await Identity.Record
                .where { $0.id.eq(identity.id) }
                .update { $0.sessionVersion = 5 }
                .execute(db)

            // Read within same transaction
            let fetched = try #require(
                try await Identity.Record
                    .where { $0.id.eq(identity.id) }
                    .fetchOne(db)
            )

            #expect(fetched.sessionVersion == 5)
        }

        // Verify persisted
        let fetched = try await database.read { db in
            try #require(
                try await Identity.Record
                    .where { $0.id.eq(identity.id) }
                    .fetchOne(db)
            )
        }

        #expect(fetched.sessionVersion == 5)
    }

    @Test("Transaction ROLLBACK reverts multiple operations")
    func testTransactionRollbackMultipleOperations() async throws {
        let email1 = TestFixtures.uniqueEmail(prefix: "multi1")
        let email2 = TestFixtures.uniqueEmail(prefix: "multi2")

        let countBefore = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        do {
            try await database.withTransaction { db in
                // Create first identity
                _ = try await TestFixtures.createTestIdentity(
                    email: email1,
                    password: TestFixtures.testPassword,
                    db: db
                )

                // Create second identity
                _ = try await TestFixtures.createTestIdentity(
                    email: email2,
                    password: TestFixtures.testPassword,
                    db: db
                )

                // Force rollback
                throw TestError.intentionalRollback
            }
        } catch TestError.intentionalRollback {
            // Expected
        }

        let countAfter = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        // Neither identity should have been created
        #expect(countBefore == countAfter)

        // Verify neither email exists
        let count = try await database.read { db in
            try await Identity.Record
                .where { $0.email.eq(email1).or($0.email.eq(email2)) }
                .asSelect()
                .fetchCount(db)
        }
        #expect(count == 0)
    }

    @Test("Concurrent transactions can create different identities")
    func testConcurrentTransactions() async throws {
        let email1 = TestFixtures.uniqueEmail(prefix: "concurrent1")
        let email2 = TestFixtures.uniqueEmail(prefix: "concurrent2")

        try await withThrowingTaskGroup(of: Identity.ID.self) { group in
            group.addTask {
                try await database.withTransaction { db in
                    let identity = try await TestFixtures.createTestIdentity(
                        email: email1,
                        password: TestFixtures.testPassword,
                        db: db
                    )
                    return identity.id
                }
            }

            group.addTask {
                try await database.withTransaction { db in
                    let identity = try await TestFixtures.createTestIdentity(
                        email: email2,
                        password: TestFixtures.testPassword,
                        db: db
                    )
                    return identity.id
                }
            }

            var ids: [Identity.ID] = []
            for try await id in group {
                ids.append(id)
            }

            #expect(ids.count == 2)
            #expect(ids[0] != ids[1])
        }

        // Verify both committed
        let count = try await database.read { db in
            try await Identity.Record
                .where { $0.email.eq(email1).or($0.email.eq(email2)) }
                .asSelect()
                .fetchCount(db)
        }

        #expect(count == 2)
    }
}
