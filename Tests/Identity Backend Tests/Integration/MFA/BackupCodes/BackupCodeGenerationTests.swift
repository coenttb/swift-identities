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
    "Backup Code Generation Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
        $0.date = .constant(Date())
    }
)
struct BackupCodeGenerationTests {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.date) var date

    @Test("Generate backup codes creates correct number of codes")
    func testGenerateBackupCodes() async throws {
        // Create identity with confirmed TOTP
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "backup-gen",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        // Setup and confirm TOTP first
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
        let codeCount = 8
        let codes = try await totpClient.generateBackupCodes(identity.id, codeCount)

        // Verify count
        #expect(codes.count == codeCount)

        // Verify all codes are unique
        let uniqueCodes = Set(codes)
        #expect(uniqueCodes.count == codeCount)

        // Verify code format (should be uppercase alphanumeric)
        for code in codes {
            #expect(code.count == config.backupCodeLength)
            #expect(code.allSatisfy { $0.isLetter || $0.isNumber })
            #expect(code.allSatisfy { $0.isUppercase || $0.isNumber })
        }

        // Verify codes saved to database
        let dbCount = try await database.read { db in
            try await Identity.MFA.BackupCodes.Record
                .findUnusedByIdentity(identity.id)
                .fetchCount(db)
        }
        #expect(dbCount == codeCount)
    }

    @Test("Regenerate backup codes invalidates old codes")
    func testRegenerateBackupCodes() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "backup-regen",
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

        // Generate initial backup codes
        let initialCodes = try await totpClient.generateBackupCodes(identity.id, 5)
        #expect(initialCodes.count == 5)

        // Verify initial codes in database
        let initialCount = try await totpClient.remainingBackupCodes(identity.id)
        #expect(initialCount == 5)

        // Regenerate backup codes
        let newCodes = try await totpClient.generateBackupCodes(identity.id, 7)
        #expect(newCodes.count == 7)

        // Verify old codes were deleted and new count is correct
        let finalCount = try await totpClient.remainingBackupCodes(identity.id)
        #expect(finalCount == 7)

        // Verify initial and new codes are different sets
        let initialSet = Set(initialCodes)
        let newSet = Set(newCodes)
        let intersection = initialSet.intersection(newSet)
        #expect(intersection.isEmpty)
    }

    @Test("Backup codes are properly encrypted")
    func testBackupCodesEncrypted() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "backup-encrypt",
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

        // Fetch backup code records from database
        let backupRecords = try await database.read { db in
            try await Identity.MFA.BackupCodes.Record
                .findUnusedByIdentity(identity.id)
                .fetchAll(db)
        }

        // Verify codes are hashed (not stored in plain text)
        for (code, record) in zip(codes, backupRecords) {
            // The hash should NOT equal the plain code
            #expect(record.codeHash != code)

            // But verification should still work
            let isValid = try await Identity.MFA.BackupCodes.Record.verifyCode(
                code,
                hash: record.codeHash
            )
            #expect(isValid == true)
        }
    }

    @Test("Backup code format validation")
    func testBackupCodeFormat() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "backup-format",
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

        // Generate codes with test configuration
        let codes = try await totpClient.generateBackupCodes(identity.id, 10)

        // Verify each code meets format requirements
        for code in codes {
            // Length should match configuration
            #expect(code.count == config.backupCodeLength)

            // Should only contain alphanumeric characters
            #expect(code.allSatisfy { char in
                char.isLetter || char.isNumber
            })

            // Should be uppercase
            #expect(code.allSatisfy { char in
                !char.isLetter || char.isUppercase
            })

            // Should not contain special characters
            #expect(!code.contains("-"))
            #expect(!code.contains("_"))
            #expect(!code.contains(" "))
        }
    }
}
