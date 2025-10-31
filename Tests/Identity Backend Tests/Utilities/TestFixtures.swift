import Dependencies
import EmailAddress
import Foundation
import Identity_Backend
import Records
import Vapor

/// Test fixtures for creating test data
enum TestFixtures {
  /// Default test email
  static let testEmail = try! EmailAddress("test@example.com")

  /// Default test password
  static let testPassword = "SecurePassword123!"

  /// Default admin email
  static let adminEmail = try! EmailAddress("admin@example.com")

  /// Generate unique email for test isolation
  /// - Parameter prefix: Email prefix (default: "test")
  /// - Returns: Unique email address with UUID suffix
  static func uniqueEmail(prefix: String = "test") -> EmailAddress {
    let uuid = UUID().uuidString.prefix(8)
    return try! EmailAddress("\(prefix)-\(uuid)@example.com")
  }

  /// Creates a test identity in the database
  static func createTestIdentity(
    email: EmailAddress = testEmail,
    password: String = testPassword,
    verified: Bool = true,
    db: any Database.Connection.`Protocol`
  ) async throws -> Identity.Record {
    let passwordHash = try Bcrypt.hash(password)

    let identity = try await Identity.Record
      .insert {
        Identity.Record.Draft(
          email: email,
          passwordHash: passwordHash,
          emailVerificationStatus: verified ? .verified : .pending,
          sessionVersion: 1
        )
      }
      .returning(\.self)
      .fetchOne(db)!

    return identity
  }

  /// Creates a test identity with unique email for test isolation
  /// - Parameters:
  ///   - emailPrefix: Prefix for generated email (default: "test")
  ///   - password: Password to hash (default: testPassword)
  ///   - verified: Whether email is verified (default: true)
  ///   - db: Database connection
  /// - Returns: Created identity record
  static func createUniqueTestIdentity(
    emailPrefix: String = "test",
    password: String = testPassword,
    verified: Bool = true,
    db: any Database.Connection.`Protocol`
  ) async throws -> Identity.Record {
    try await createTestIdentity(
      email: uniqueEmail(prefix: emailPrefix),
      password: password,
      verified: verified,
      db: db
    )
  }

  /// Creates multiple test identities with unique emails
  static func createTestIdentities(
    count: Int,
    db: any Database.Connection.`Protocol`
  ) async throws -> [Identity.Record] {
    var identities: [Identity.Record] = []

    for i in 0..<count {
      let email = try EmailAddress("test\(i)@example.com")
      let identity = try await createTestIdentity(
        email: email,
        db: db
      )
      identities.append(identity)
    }

    return identities
  }
}
