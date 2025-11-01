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

/// Tests for the audit logging system
///
/// These tests verify that database triggers properly capture changes
/// to security-critical tables (identities, API keys, TOTP).
@Suite(
    "Audit Logging Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
    }
)
struct AuditTests {
    @Dependency(\.defaultDatabase) var database

    // MARK: - Identity Table Auditing

    @Test("INSERT on identities creates audit record")
    func testIdentityInsertAudit() async throws {
        let email = TestFixtures.uniqueEmail(prefix: "audit-insert")

        // Create identity
        _ = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: email,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Verify audit record was created
        let audits = try await Identity.Audit.recentIdentityChanges(limit: 10)

        // Find the INSERT for our identity
        let insertAudits = audits.filter { $0.operation == "INSERT" }
        #expect(insertAudits.count >= 1)

        let audit = try #require(insertAudits.first)
        #expect(audit.tableName == "identities")
        #expect(audit.operation == "INSERT")
        #expect(audit.oldData == nil)
        #expect(audit.newData != nil)
        #expect(audit.newData?.contains(email.rawValue) == true)
    }

    @Test("UPDATE on identities creates audit record")
    func testIdentityUpdateAudit() async throws {
        let oldEmail = TestFixtures.uniqueEmail(prefix: "audit-old")
        let newEmail = TestFixtures.uniqueEmail(prefix: "audit-new")

        // Create identity
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

        // Verify audit record - get recent updates
        let audits = try await Identity.Audit.recentIdentityChanges(limit: 10)
        let updateAudits = audits.filter { $0.operation == "UPDATE" }

        #expect(updateAudits.count >= 1)
        let audit = try #require(updateAudits.first)

        #expect(audit.operation == "UPDATE")
        #expect(audit.oldData?.contains(oldEmail.rawValue) == true)
        #expect(audit.newData?.contains(newEmail.rawValue) == true)
    }

    @Test("DELETE on identities creates audit record")
    func testIdentityDeleteAudit() async throws {
        let email = TestFixtures.uniqueEmail(prefix: "audit-delete")

        // Create identity
        let identity = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: email,
                password: TestFixtures.testPassword,
                db: db
            )
        }

        // Delete identity
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(identity.id) }
                .delete()
                .execute(db)
        }

        // Verify audit record
        let audits = try await Identity.Audit.recentDeletions(limit: 10)

        #expect(audits.count >= 1)
        let audit = try #require(audits.first)

        #expect(audit.operation == "DELETE")
        #expect(audit.oldData?.contains(email.rawValue) == true)
        #expect(audit.newData == nil)
    }

    // MARK: - Password Change Auditing

    @Test("Password changes are audited")
    func testPasswordChangeAudit() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "password-audit",
                db: db
            )
        }

        let oldHash = identity.passwordHash
        let newHash = try Bcrypt.hash("NewPassword123!")

        // Update password
        try await database.write { db in
            try await Identity.Record
                .where { $0.id.eq(identity.id) }
                .update { $0.passwordHash = newHash }
                .execute(db)
        }

        // Query recent identity changes
        let audits = try await Identity.Audit.recentIdentityChanges(limit: 10)
        let passwordChanges = audits.filter { audit in
            audit.operation == "UPDATE" &&
            audit.newData?.contains("passwordHash") == true
        }

        #expect(passwordChanges.count >= 1)
        let audit = try #require(passwordChanges.first)

        #expect(audit.oldData?.contains(oldHash) == true)
        #expect(audit.newData?.contains(newHash) == true)
    }

    // MARK: - API Key Auditing

    @Test("API key creation is audited")
    func testApiKeyCreationAudit() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "apikey-audit",
                db: db
            )
        }

        // Create API key
        do {
            try await database.write { db in
                try await Identity.Authentication.ApiKey.Record
                    .insert {
                        Identity.Authentication.ApiKey.Record.Draft(
                            name: "Test Key",
                            key: "test-key-\(UUID().uuidString)",
                            scopes: [],
                            identityId: identity.id,
                            validUntil: Date().addingTimeInterval(86400)
                        )
                    }
                    .execute(db)
            }
        } catch {
            print("❌ API Key Creation Error:")
            print(String(reflecting: error))
            throw error
        }

        // Verify audit record
        let audits = try await Identity.Audit.recentAPIKeyChanges(limit: 10)
        let insertAudits = audits.filter { $0.operation == "INSERT" }

        #expect(insertAudits.count >= 1)
        let audit = try #require(insertAudits.first)

        #expect(audit.operation == "INSERT")
        #expect(audit.newData?.contains("Test Key") == true)
    }

    @Test("API key deactivation is audited")
    func testApiKeyDeactivationAudit() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "apikey-deactivate",
                db: db
            )
        }

        // Create active API key and get its ID
        let apiKeyId: Identity.Authentication.ApiKey.Record.ID
        do {
            apiKeyId = try #require(
                try await database.write { db in
                    try await Identity.Authentication.ApiKey.Record
                        .insert {
                            Identity.Authentication.ApiKey.Record.Draft(
                                name: "Active Key",
                                key: "active-key-\(UUID().uuidString)",
                                scopes: [],
                                identityId: identity.id,
                                validUntil: Date().addingTimeInterval(86400)
                            )
                        }
                        .returning { $0.id }
                        .fetchOne(db)
                }
            )
        } catch {
            print("❌ API Key Deactivation Test - Creation Error:")
            print(String(reflecting: error))
            throw error
        }

        // Deactivate it
        try await database.write { db in
            try await Identity.Authentication.ApiKey.Record
                .where { $0.id.eq(apiKeyId) }
                .update { $0.isActive = false }
                .execute(db)
        }

        // Verify audit shows activation status change
        let audits = try await Identity.Audit.recentAPIKeyChanges(limit: 10)
        let updateAudits = audits.filter { audit in
            audit.operation == "UPDATE" &&
            audit.newData?.contains("\"isActive\": false") == true
        }

        #expect(updateAudits.count >= 1)
        let audit = try #require(updateAudits.first)

        #expect(audit.oldData?.contains("\"isActive\": true") == true)
        #expect(audit.newData?.contains("\"isActive\": false") == true)
    }

    // MARK: - TOTP/MFA Auditing

    @Test("TOTP setup is audited")
    func testTotpSetupAudit() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-audit",
                db: db
            )
        }

        // Create TOTP record
        try await database.write { db in
            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: "TESTSECRET",
                        isConfirmed: false,
                        algorithm: .sha1,
                        digits: 6,
                        timeStep: 30,
                        createdAt: Date(),
                        confirmedAt: nil,
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                }
                .execute(db)
        }

        // Verify audit record
        let audits = try await Identity.Audit.recentMFAChanges(limit: 10)
        let insertAudits = audits.filter { $0.operation == "INSERT" }

        #expect(insertAudits.count >= 1)
        let audit = try #require(insertAudits.first)

        #expect(audit.operation == "INSERT")
        #expect(audit.tableName == "identity_totp")
        #expect(audit.newData != nil)
    }

    @Test("TOTP confirmation is audited")
    func testTotpConfirmationAudit() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-confirm",
                db: db
            )
        }

        // Create unconfirmed TOTP and get its ID
        let totpId: Identity.MFA.TOTP.Record.ID = try #require(
            try await database.write { db in
                try await Identity.MFA.TOTP.Record
                    .insert {
                        Identity.MFA.TOTP.Record.Draft(
                            identityId: identity.id,
                            secret: "TESTSECRET",
                            isConfirmed: false,
                            algorithm: .sha1,
                            digits: 6,
                            timeStep: 30,
                            createdAt: Date(),
                            confirmedAt: nil,
                            lastUsedAt: nil,
                            usageCount: 0
                        )
                    }
                    .returning { $0.id }
                    .fetchOne(db)
            }
        )

        // Confirm it
        try await database.write { db in
            try await Identity.MFA.TOTP.Record
                .where { $0.id.eq(totpId) }
                .update { record in
                    record.isConfirmed = true
                    record.confirmedAt = Date()
                }
                .execute(db)
        }

        // Verify audit shows confirmation
        let audits = try await Identity.Audit.recentMFAChanges(limit: 10)
        let updateAudits = audits.filter { $0.operation == "UPDATE" }

        #expect(updateAudits.count >= 1)
        let audit = try #require(updateAudits.first)

        #expect(audit.operation == "UPDATE")
        #expect(audit.tableName == "identity_totp")
        // Verify that it captured both old and new data
        #expect(audit.oldData != nil)
        #expect(audit.newData != nil)
    }

    // MARK: - Query Helper Tests

    @Test("recentSecurityChanges returns cross-table changes")
    func testRecentSecurityChanges() async throws {
        let since = Date()

        // Create identity (audited)
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "security",
                db: db
            )
        }

        // Create API key (audited)
        do {
            try await database.write { db in
                try await Identity.Authentication.ApiKey.Record
                    .insert {
                        Identity.Authentication.ApiKey.Record.Draft(
                            name: "Test Key",
                            key: "key-\(UUID().uuidString)",
                            scopes: [],
                            identityId: identity.id,
                            validUntil: Date().addingTimeInterval(86400)
                        )
                    }
                    .execute(db)
            }
        } catch {
            print("❌ Recent Security Changes Test - API Key Creation Error:")
            print(String(reflecting: error))
            throw error
        }

        // Get recent security changes
        let changes = try await Identity.Audit.recentSecurityChanges(
            since: since,
            limit: 100
        )

        // Should have at least 2 records (identity + api key)
        #expect(changes.count >= 2)

        // Verify they're from audited tables
        for change in changes {
            #expect(["identities", "identity_api_keys", "identity_totp"].contains(change.tableName))
        }
    }

    @Test("Audit records are timestamped correctly")
    func testAuditTimestamps() async throws {
        let before = Date()

        _ = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "timestamp",
                db: db
            )
        }

        let after = Date()

        let audits = try await Identity.Audit.recentIdentityChanges(limit: 1)
        let audit = try #require(audits.first)

        // Timestamp should be between before and after
        #expect(audit.changedAt >= before)
        #expect(audit.changedAt <= after)
    }

    @Test("historyFor returns table-specific changes")
    func testHistoryFor() async throws {
        // Create an identity (creates audit in identities table)
        _ = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "history",
                db: db
            )
        }

        // Get history for identities table
        let history = try await Identity.Audit.historyFor(
            tableName: "identities",
            limit: 100
        )

        // Should have at least one record
        #expect(history.count >= 1)

        // All should be from identities table
        for audit in history {
            #expect(audit.tableName == "identities")
        }
    }
}
