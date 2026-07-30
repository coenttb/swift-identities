import Dependencies
import Dependencies_Test_Support
import EmailAddress
import Foundation
import IdentitiesTypes
import Identity_Backend
import Records
import RecordsTestSupport
import Testing

@Suite(

    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
        $0.date = .constant(Date())
    }
)
struct Test {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.date) var date

    @Test
    func `TOTP generate Secret creates valid secret and QR code URL`() async throws {
        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        // Generate secret
        let setupData = try await totpClient.generateSecret()

        // Verify secret format (base32)
        #expect(setupData.secret.count > 0)
        #expect(setupData.secret.allSatisfy { "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".contains($0) })

        // Verify QR code URL format
        let urlString = setupData.qrCodeURL.absoluteString
        #expect(urlString.hasPrefix("otpauth://totp/"))
        #expect(urlString.contains("secret=\(setupData.secret)"))
        #expect(urlString.contains("issuer=Test"))
        #expect(urlString.contains("algorithm=SHA1"))
        #expect(urlString.contains("digits=6"))
        #expect(urlString.contains("period=10"))

        // Verify manual entry key format (has spaces)
        #expect(setupData.manualEntryKey.contains(" "))
        #expect(!setupData.manualEntryKey.isEmpty)
    }

    @Test
    func `TOTP setup creates unconfirmed TOTP record in database`() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-setup",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        // Setup TOTP
        let setupData = try await totpClient.generateSecret()

        // Manually create TOTP record (since setup() requires auth)
        try await database.write { db in
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)

            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: false,
                        algorithm: .sha1,
                        digits: 6,
                        timeStep: 10,
                        createdAt: Date(),
                        confirmedAt: nil,
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                }
                .execute(db)
        }

        // Verify record created
        let totpRecord = try #require(
            try await database.read { db in
                try await Identity.MFA.TOTP.Record
                    .findByIdentity(identity.id)
                    .fetchOne(db)
            }
        )

        #expect(totpRecord.identityId == identity.id)
        #expect(totpRecord.isConfirmed == false)
        #expect(totpRecord.confirmedAt == nil)
        #expect(totpRecord.usageCount == 0)
        #expect(totpRecord.lastUsedAt == nil)
    }

    @Test
    func `TOTP confirm Setup with valid code marks record as confirmed`() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-confirm",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        let setupData = try await totpClient.generateSecret()

        // Create TOTP record
        try await database.write { db in
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)

            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: false,
                        algorithm: .sha1,
                        digits: 6,
                        timeStep: 10,
                        createdAt: Date(),
                        confirmedAt: nil,
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                }
                .execute(db)
        }

        // Inject a deterministic verifier in place of real TOTP validation
        let validCode = "246810"

        // Confirm setup
        try await withDependencies {
            $0[Identity.MFA.TOTP.Verifier.self] = .init { code, _, _ in code == validCode }
        } operation: {
            try await totpClient.confirmSetup(identity.id, setupData.secret, validCode)
        }

        // Verify confirmation
        let confirmed = try #require(
            try await database.read { db in
                try await Identity.MFA.TOTP.Record
                    .findByIdentity(identity.id)
                    .fetchOne(db)
            }
        )

        #expect(confirmed.isConfirmed == true)
        #expect(confirmed.confirmedAt != nil)

        // Verify confirmedAt is recent (timezone-tolerant check)
        let age = abs(confirmed.confirmedAt!.timeIntervalSinceNow)
        #expect(age < 3600)  // Within last hour (accounts for timezone differences)
    }

    @Test
    func `TOTP confirm Setup with invalid code throws error`() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-invalid",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        let setupData = try await totpClient.generateSecret()

        // Create TOTP record
        try await database.write { db in
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)

            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: false,
                        algorithm: .sha1,
                        digits: 6,
                        timeStep: 10,
                        createdAt: Date(),
                        confirmedAt: nil,
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                }
                .execute(db)
        }

        // Attempt to confirm with an invalid code under real TOTP validation
        await #expect(throws: (any Error).self) {
            try await totpClient.confirmSetup(identity.id, setupData.secret, "999999")
        }

        // Verify still unconfirmed
        let stillUnconfirmed = try #require(
            try await database.read { db in
                try await Identity.MFA.TOTP.Record
                    .findByIdentity(identity.id)
                    .fetchOne(db)
            }
        )

        #expect(stillUnconfirmed.isConfirmed == false)
        #expect(stillUnconfirmed.confirmedAt == nil)
    }

    @Test
    func `TOTP is Enabled returns true after confirmation`() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-enabled",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        // Before setup
        let beforeSetup = try await totpClient.isEnabled(identity.id)
        #expect(beforeSetup == false)

        let setupData = try await totpClient.generateSecret()

        // Create and confirm TOTP record
        try await database.write { db in
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)

            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: true,  // Directly set as confirmed
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

        // After confirmation
        let afterConfirmation = try await totpClient.isEnabled(identity.id)
        #expect(afterConfirmation == true)
    }

    @Test
    func `TOTP is Enabled returns false before confirmation`() async throws {
        let identity = try await database.write { db in
            try await TestFixtures.createUniqueTestIdentity(
                emailPrefix: "totp-notconfirmed",
                db: db
            )
        }

        let config = Identity.MFA.TOTP.Configuration.test
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

        let setupData = try await totpClient.generateSecret()

        // Create unconfirmed TOTP record
        try await database.write { db in
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)

            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: false,
                        algorithm: .sha1,
                        digits: 6,
                        timeStep: 10,
                        createdAt: Date(),
                        confirmedAt: nil,
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                }
                .execute(db)
        }

        // Should return false for unconfirmed TOTP
        let isEnabled = try await totpClient.isEnabled(identity.id)
        #expect(isEnabled == false)
    }
}
