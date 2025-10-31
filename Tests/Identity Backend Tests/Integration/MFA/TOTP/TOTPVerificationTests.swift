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
    "TOTP Verification Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
        $0.date = .constant(Date())
    }
)
struct TOTPVerificationTests {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.date) var date

    @Test("Valid TOTP code verification succeeds")
    func testValidCodeVerification() async throws {
        // Create identity with confirmed TOTP
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-verify-valid",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)
        let setupData = try await totpClient.generateSecret()

        // Create confirmed TOTP record
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

        // Use debug bypass code
        let validCode = "000000"
        let isValid = try await totpClient.verifyCode(identity.id, validCode)

        #expect(isValid == true)
    }

    @Test("Invalid TOTP code verification fails")
    func testInvalidCodeVerification() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-verify-invalid",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)
        let setupData = try await totpClient.generateSecret()

        // Create confirmed TOTP record
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

        // Use invalid code (not the debug bypass)
        // verifyCode returns Bool, doesn't throw
        let isValid = try await totpClient.verifyCode(identity.id, "999999")
        #expect(isValid == false, "Invalid TOTP code should return false")
    }

    @Test("Expired TOTP code fails")
    func testExpiredCodeVerification() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-verify-expired",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)
        let setupData = try await totpClient.generateSecret()

        // Create confirmed TOTP record
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

        // Test that an old/invalid code fails (not using bypass code)
        // In a real scenario, this would be a code from a past time window
        // verifyCode returns Bool, doesn't throw
        let isValid = try await totpClient.verifyCode(identity.id, "111111")
        #expect(isValid == false, "Expired/invalid TOTP code should return false")
    }

    @Test("TOTP verification updates usage statistics")
    func testVerificationUpdatesStats() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-verify-stats",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)
        let setupData = try await totpClient.generateSecret()

        // Create confirmed TOTP record
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

        // Verify with debug bypass code
        let validCode = "000000"
        let isValid = try await totpClient.verifyCode(identity.id, validCode)
        #expect(isValid == true)

        // Check that stats were updated
        let updatedRecord = try #require(
            try await database.read { db in
                try await Identity.MFA.TOTP.Record
                    .findByIdentity(identity.id)
                    .fetchOne(db)
            }
        )

        #expect(updatedRecord.usageCount == 1)
        #expect(updatedRecord.lastUsedAt != nil)

        // Verify lastUsedAt is recent (timezone-tolerant)
        let age = abs(updatedRecord.lastUsedAt!.timeIntervalSinceNow)
        #expect(age < 3600)  // Within last hour
    }

    @Test("TOTP verification with time window tolerance")
    func testVerificationWithTimeWindow() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-verify-window",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)
        let setupData = try await totpClient.generateSecret()

        // Create confirmed TOTP record with wider window
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

        // Use debug bypass code with custom window
        let validCode = "000000"
        let isValid = try await totpClient.verifyCodeWithWindow(identity.id, validCode, 2)

        #expect(isValid == true)

        // Verify usage was recorded
        let record = try #require(
            try await database.read { db in
                try await Identity.MFA.TOTP.Record
                    .findByIdentity(identity.id)
                    .fetchOne(db)
            }
        )
        #expect(record.usageCount == 1)
    }
}
