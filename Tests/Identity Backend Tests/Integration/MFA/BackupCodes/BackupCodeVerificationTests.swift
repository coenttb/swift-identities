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

    @Test("Multiple backup codes can be used sequentially")
    func testMultipleBackupCodeUsage() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "backup-verify-multiple",
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

        // Verify initial count
        let initialRemaining = try await totpClient.remainingBackupCodes(identity.id)
        #expect(initialRemaining == 10)

        // Use three different codes sequentially
        let code1Valid = try await totpClient.verifyBackupCode(identity.id, codes[0])
        #expect(code1Valid == true, "First backup code should be valid")

        let code2Valid = try await totpClient.verifyBackupCode(identity.id, codes[1])
        #expect(code2Valid == true, "Second backup code should be valid")

        let code3Valid = try await totpClient.verifyBackupCode(identity.id, codes[2])
        #expect(code3Valid == true, "Third backup code should be valid")

        // Verify correct number of codes remain
        let finalRemaining = try await totpClient.remainingBackupCodes(identity.id)
        #expect(finalRemaining == 7, "Should have 7 codes remaining after using 3")
    }
}
