import Dependencies
import DependenciesTestSupport
import EmailAddress
import Foundation
import IdentitiesTypes
import Identity_Backend
import Records
import RecordsTestSupport
import Testing
import Vapor

@Suite(
  "Identity Creation Tests",
  .dependencies {
    $0.envVars = .development
    $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
  }
)
struct IdentityCreationTests {
  @Dependency(\.defaultDatabase) var database

  @Test("INSERT identity with all required fields succeeds")
  func testCreateIdentityWithRequiredFields() async throws {
    let email = TestFixtures.uniqueEmail(prefix: "create")
    let password = TestFixtures.testPassword

    let identity = try await database.write { db in
      try await TestFixtures.createTestIdentity(
        email: email,
        password: password,
        verified: false,
        db: db
      )
    }

    #expect(identity.email == email)
    #expect(!identity.passwordHash.isEmpty)
    #expect(identity.emailVerificationStatus == .pending)
    #expect(identity.sessionVersion == 1)
    // createdAt is set by database, just verify it exists
    #expect(identity.createdAt.timeIntervalSinceNow < 3600)  // Within last hour
    #expect(identity.lastLoginAt == nil)
  }

  @Test("INSERT identity with verified email status")
  func testCreateVerifiedIdentity() async throws {
    let email = TestFixtures.uniqueEmail(prefix: "verified")

    let identity = try await database.write { db in
      try await TestFixtures.createTestIdentity(
        email: email,
        password: TestFixtures.testPassword,
        verified: true,
        db: db
      )
    }

    #expect(identity.emailVerificationStatus == .verified)
  }

  @Test("INSERT identity generates unique UUID for id")
  func testIdentityHasUniqueId() async throws {
    let identity1 = try await database.write { db in
      try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "uuid1",
        db: db
      )
    }

    let identity2 = try await database.write { db in
      try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "uuid2",
        db: db
      )
    }

    #expect(identity1.id != identity2.id)
  }

  @Test("INSERT identity sets createdAt timestamp")
  func testIdentityCreatedAtTimestamp() async throws {
    let identity = try await database.write { db in
      try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "timestamp",
        db: db
      )
    }

    // Verify timestamp is recent (within last hour to account for timezone)
    let age = abs(identity.createdAt.timeIntervalSinceNow)
    #expect(age < 3600)  // Less than 1 hour old
  }

  @Test("INSERT identity initializes sessionVersion to 1")
  func testIdentityInitialSessionVersion() async throws {
    let identity = try await database.write { db in
      try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "session",
        db: db
      )
    }

    #expect(identity.sessionVersion == 1)
  }

  @Test("INSERT identity leaves lastLoginAt as nil")
  func testIdentityInitialLastLoginAt() async throws {
    let identity = try await database.write { db in
      try await TestFixtures.createUniqueTestIdentity(
        emailPrefix: "lastlogin",
        db: db
      )
    }

    #expect(identity.lastLoginAt == nil)
  }

  @Test("INSERT identity hashes password with bcrypt")
  func testIdentityPasswordHashing() async throws {
    let password = "TestPassword123!"
    let email = TestFixtures.uniqueEmail(prefix: "bcrypt")

    let identity = try await database.write { db in
      try await TestFixtures.createTestIdentity(
        email: email,
        password: password,
        db: db
      )
    }

    // Verify hash format (bcrypt hashes start with $2)
    #expect(identity.passwordHash.hasPrefix("$2"))
    #expect(identity.passwordHash.count > 50)

    // Verify hash is correct
    let isValid = try Bcrypt.verify(password, created: identity.passwordHash)
    #expect(isValid == true)

    // Verify original password is not stored
    #expect(identity.passwordHash != password)
  }

  @Test("INSERT multiple identities in sequence")
  func testCreateMultipleIdentities() async throws {
    let count = 5
    var createdIds: [Identity.ID] = []

    for i in 0..<count {
      let identity = try await database.write { db in
        try await TestFixtures.createTestIdentity(
          email: try EmailAddress("multi\(i)@example.com"),
          password: TestFixtures.testPassword,
          db: db
        )
      }
      createdIds.append(identity.id)
    }

    // Verify all were created
    let ids = createdIds  // Capture as immutable for sendability
    let fetchedCount = try await database.read { db in
      try await Identity.Record
        .where { ids.contains($0.id) }
        .asSelect()
        .fetchCount(db)
    }

    #expect(fetchedCount == count)
  }

  @Test("SELECT created identity by ID returns correct record")
  func testFetchIdentityById() async throws {
    let email = TestFixtures.uniqueEmail(prefix: "fetchbyid")

    let created = try await database.write { db in
      try await TestFixtures.createTestIdentity(
        email: email,
        password: TestFixtures.testPassword,
        db: db
      )
    }

    let fetched = try await database.read { db in
      try await Identity.Record
        .where { $0.id.eq(created.id) }
        .fetchOne(db)
    }

    let identity = try #require(fetched)
    #expect(identity.id == created.id)
    #expect(identity.email == email)
    #expect(identity.passwordHash == created.passwordHash)
  }

  @Test("SELECT created identity by email returns correct record")
  func testFetchIdentityByEmail() async throws {
    let email = TestFixtures.uniqueEmail(prefix: "fetchbyemail")

    _ = try await database.write { db in
      try await TestFixtures.createTestIdentity(
        email: email,
        password: TestFixtures.testPassword,
        db: db
      )
    }

    let fetched = try await database.read { db in
      try await Identity.Record
        .where { $0.email.eq(email) }
        .fetchOne(db)
    }

    let identity = try #require(fetched)
    #expect(identity.email == email)
  }

  @Test("SELECT returns nil for non-existent identity")
  func testFetchNonExistentIdentity() async throws {
    let nonExistentId = Identity.ID(UUID())

    let fetched = try await database.read { db in
      try await Identity.Record
        .where { $0.id.eq(nonExistentId) }
        .fetchOne(db)
    }

    #expect(fetched == nil)
  }

  @Test("COUNT identities returns correct number")
  func testCountIdentities() async throws {
    let countBefore = try await database.read { db in
      try await Identity.Record.fetchCount(db)
    }

    // Create 3 identities
    for i in 0..<3 {
      _ = try await database.write { db in
        try await TestFixtures.createTestIdentity(
          email: try EmailAddress("count\(i)@example.com"),
          password: TestFixtures.testPassword,
          db: db
        )
      }
    }

    let countAfter = try await database.read { db in
      try await Identity.Record.fetchCount(db)
    }

    #expect(countAfter == countBefore + 3)
  }
}
