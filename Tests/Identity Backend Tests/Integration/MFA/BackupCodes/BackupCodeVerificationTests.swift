import Dependencies
import DependenciesTestSupport
import EmailAddress
import Foundation
import Identity_Backend
import IdentitiesTypes
import Records
import RecordsTestSupport
import Testing

@Suite(
    "Backup Code Verification Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
        $0.date = .constant(Date())
    }
)
struct BackupCodeVerificationTests {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.date) var date

    @Test("Valid backup code verification succeeds and marks as used")
    func testValidBackupCodeVerification() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "backup-verify-valid",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        // Setup TOTP
        let setupData = try await totpClient.generateSecret()
        try await database.write { db in
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)

            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: true,
                        algorithm: .sha1,
                        digits: 6,
                        timeStep: 10,
                        createdAt: Date(),
                        confirmedAt: Date(),
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                }
                .execute(db)
        }

        // Generate backup codes
        let codes = try await totpClient.generateBackupCodes(identity.id, 5)
        let testCode = codes[0]

        // Verify the code
        let isValid = try await totpClient.verifyBackupCode(identity.id, testCode)
        #expect(isValid == true)

        // Verify code is marked as used in database
        let backupRecords = try await database.read { db in
            try await Identity.MFA.BackupCodes.Record
                .where { $0.identityId.eq(identity.id) }
                .fetchAll(db)
        }

        // Find the used code
        let usedRecord = backupRecords.first { $0.isUsed }
        #expect(usedRecord != nil)
        #expect(usedRecord?.usedAt != nil)

        // Verify usedAt is recent (timezone-tolerant)
        if let usedRecord = usedRecord, let usedAt = usedRecord.usedAt {
            let age = abs(usedAt.timeIntervalSinceNow)
            #expect(age < 3600)  // Within last hour
        }

        // Verify remaining count decreased
        let remaining = try await totpClient.remainingBackupCodes(identity.id)
        #expect(remaining == 4)
    }

    @Test("Invalid backup code verification fails")
    func testInvalidBackupCodeVerification() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "backup-verify-invalid",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        // Setup TOTP
        let setupData = try await totpClient.generateSecret()
        try await database.write { db in
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)

            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: true,
                        algorithm: .sha1,
                        digits: 6,
                        timeStep: 10,
                        createdAt: Date(),
                        confirmedAt: Date(),
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                }
                .execute(db)
        }

        // Generate backup codes
        _ = try await totpClient.generateBackupCodes(identity.id, 5)

        // Try to verify with invalid code
        let invalidCode = "INVALID123"
        let isValid = try await totpClient.verifyBackupCode(identity.id, invalidCode)
        #expect(isValid == false)

        // Verify no codes were marked as used
        let unusedCount = try await totpClient.remainingBackupCodes(identity.id)
        #expect(unusedCount == 5)
    }

    @Test("Used backup code cannot be reused")
    func testUsedBackupCodeCannotBeReused() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "backup-verify-reuse",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        // Setup TOTP
        let setupData = try await totpClient.generateSecret()
        try await database.write { db in
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)

            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: true,
                        algorithm: .sha1,
                        digits: 6,
                        timeStep: 10,
                        createdAt: Date(),
                        confirmedAt: Date(),
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                }
                .execute(db)
        }

        // Generate backup codes
        let codes = try await totpClient.generateBackupCodes(identity.id, 5)
        let testCode = codes[0]

        // Use the code first time
        let firstUse = try await totpClient.verifyBackupCode(identity.id, testCode)
        #expect(firstUse == true)

        // Verify remaining count
        let afterFirst = try await totpClient.remainingBackupCodes(identity.id)
        #expect(afterFirst == 4)

        // Try to use the same code again
        let secondUse = try await totpClient.verifyBackupCode(identity.id, testCode)
        #expect(secondUse == false)

        // Verify count didn't change
        let afterSecond = try await totpClient.remainingBackupCodes(identity.id)
        #expect(afterSecond == 4)
    }

    @Test("Concurrent backup code usage handling")
    func testConcurrentBackupCodeUsage() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "backup-verify-concurrent",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        // Setup TOTP
        let setupData = try await totpClient.generateSecret()
        try await database.write { db in
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)

            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: true,
                        algorithm: .sha1,
                        digits: 6,
                        timeStep: 10,
                        createdAt: Date(),
                        confirmedAt: Date(),
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                }
                .execute(db)
        }

        // Generate backup codes
        let codes = try await totpClient.generateBackupCodes(identity.id, 10)

        // Try to use the same code concurrently
        let sameCode = codes[0]

        // Run concurrent verifications
        async let result1 = totpClient.verifyBackupCode(identity.id, sameCode)
        async let result2 = totpClient.verifyBackupCode(identity.id, sameCode)
        async let result3 = totpClient.verifyBackupCode(identity.id, sameCode)

        let results = try await [result1, result2, result3]

        // Only one should succeed (due to transaction handling)
        let successCount = results.filter { $0 }.count
        #expect(successCount == 1)

        // Verify only one code was used
        let remaining = try await totpClient.remainingBackupCodes(identity.id)
        #expect(remaining == 9)

        // Test using different codes concurrently (should all succeed)
        let code1 = codes[1]
        let code2 = codes[2]
        let code3 = codes[3]

        async let diffResult1 = totpClient.verifyBackupCode(identity.id, code1)
        async let diffResult2 = totpClient.verifyBackupCode(identity.id, code2)
        async let diffResult3 = totpClient.verifyBackupCode(identity.id, code3)

        let diffResults = try await [diffResult1, diffResult2, diffResult3]

        // All different codes should succeed
        #expect(diffResults.allSatisfy { $0 })

        // Verify correct number of codes remain
        let finalRemaining = try await totpClient.remainingBackupCodes(identity.id)
        #expect(finalRemaining == 6)
    }
}
