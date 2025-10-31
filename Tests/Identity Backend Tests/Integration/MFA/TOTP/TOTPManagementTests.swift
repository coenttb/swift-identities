import Dependencies
import DependenciesTestSupport
import EmailAddress
import Foundation
import IdentitiesTypes
import Identity_Backend
import Records
import RecordsTestSupport
import Testing

@Suite(
  "TOTP Management Tests",
  .dependencies {
    $0.envVars = .development
    $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
    $0.date = .constant(Date())
  }
)
struct TOTPManagementTests {
  @Dependency(\.defaultDatabase) var database
  @Dependency(\.date) var date

  @Test("Get TOTP status returns correct information")
  func testGetStatus() async throws {
    let identity = try await database.write { db in
      try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "totp-status",
        db: db
      )
    }

    let config = Identity.MFA.TOTP.Configuration.test
    let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

    // Initially, TOTP should not be enabled
    let initialStatus = try await totpClient.getStatus(identity.id)
    #expect(initialStatus.isEnabled == false)
    #expect(initialStatus.isConfirmed == false)
    #expect(initialStatus.backupCodesRemaining == 0)
    #expect(initialStatus.lastUsedAt == nil)

    // Setup and confirm TOTP
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
    let backupCodes = try await totpClient.generateBackupCodes(identity.id, 5)
    #expect(backupCodes.count == 5)

    // Check status after setup
    let afterSetupStatus = try await totpClient.getStatus(identity.id)
    #expect(afterSetupStatus.isEnabled == true)
    #expect(afterSetupStatus.isConfirmed == true)
    #expect(afterSetupStatus.backupCodesRemaining == 5)
    #expect(afterSetupStatus.lastUsedAt == nil)
  }

  @Test("Disable TOTP removes record from database")
  func testDisableTOTP() async throws {
    let identity = try await database.write { db in
      try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "totp-disable",
        db: db
      )
    }

    let config = Identity.MFA.TOTP.Configuration.test
    let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

    // Setup and confirm TOTP
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

    // Verify TOTP is enabled
    let beforeDisable = try await totpClient.isEnabled(identity.id)
    #expect(beforeDisable == true)

    // Disable TOTP
    try await totpClient.disable(identity.id)

    // Verify TOTP is disabled
    let afterDisable = try await totpClient.isEnabled(identity.id)
    #expect(afterDisable == false)

    // Verify record removed from database
    let totpRecord = try await database.read { db in
      try await Identity.MFA.TOTP.Record
        .findByIdentity(identity.id)
        .fetchOne(db)
    }
    #expect(totpRecord == nil)

    // Verify backup codes also removed
    let backupCount = try await totpClient.remainingBackupCodes(identity.id)
    #expect(backupCount == 0)
  }

  @Test("QR code generation for existing TOTP")
  func testQRCodeGeneration() async throws {
    let identity = try await database.write { db in
      try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "totp-qr",
        db: db
      )
    }

    let config = Identity.MFA.TOTP.Configuration.test
    let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

    // Generate secret
    let setupData = try await totpClient.generateSecret()

    // Generate QR code URL
    let qrCodeURL = try await totpClient.generateQRCodeURL(
      setupData.secret,
      identity.email.rawValue,
      "TestIssuer"
    )

    // Verify URL format
    let urlString = qrCodeURL.absoluteString
    #expect(urlString.hasPrefix("otpauth://totp/"))
    #expect(urlString.contains("secret=\(setupData.secret)"))
    #expect(urlString.contains("issuer=TestIssuer"))
    #expect(urlString.contains(identity.email.rawValue))
  }

  @Test("Multiple identities can have separate TOTP configs")
  func testMultipleIdentitiesSeparateTOTP() async throws {
    // Create two identities
    let (identity1, identity2) = try await database.write { db in
      let id1 = try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "totp-multi-1",
        db: db
      )
      let id2 = try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "totp-multi-2",
        db: db
      )
      return (id1, id2)
    }

    let config = Identity.MFA.TOTP.Configuration.test
    let totpClient = Identity.MFA.TOTP.Client.backend(configuration: config)

    // Setup TOTP for both identities with different secrets
    let setupData1 = try await totpClient.generateSecret()
    let setupData2 = try await totpClient.generateSecret()

    // Verify secrets are different
    #expect(setupData1.secret != setupData2.secret)

    // Create TOTP records for both
    try await database.write { db in
      let encrypted1 = try Identity.MFA.TOTP.Record.encryptSecret(setupData1.secret)
      let encrypted2 = try Identity.MFA.TOTP.Record.encryptSecret(setupData2.secret)

      try await Identity.MFA.TOTP.Record
        .insert {
          Identity.MFA.TOTP.Record.Draft(
            identityId: identity1.id,
            secret: encrypted1,
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

      try await Identity.MFA.TOTP.Record
        .insert {
          Identity.MFA.TOTP.Record.Draft(
            identityId: identity2.id,
            secret: encrypted2,
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

    // Verify both are enabled independently
    let enabled1 = try await totpClient.isEnabled(identity1.id)
    let enabled2 = try await totpClient.isEnabled(identity2.id)
    #expect(enabled1 == true)
    #expect(enabled2 == true)

    // Disable identity1's TOTP
    try await totpClient.disable(identity1.id)

    // Verify identity1 disabled but identity2 still enabled
    let afterDisable1 = try await totpClient.isEnabled(identity1.id)
    let afterDisable2 = try await totpClient.isEnabled(identity2.id)
    #expect(afterDisable1 == false)
    #expect(afterDisable2 == true)
  }
}
