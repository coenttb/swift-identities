import Dependencies
import EmailAddress
import Foundation
import Identity_Backend
import Records

/// Test fixtures for creating test data
enum TestFixtures {
    /// Default test email
    static let testEmail = try! EmailAddress("test@example.com")

    /// Default test password
    static let testPassword = "SecurePassword123!"

    /// Default admin email
    static let adminEmail = try! EmailAddress("admin@example.com")

    /// Creates a test identity in the database
    static func createTestIdentity(
        email: EmailAddress = testEmail,
        password: String = testPassword,
        verified: Bool = true,
        db: any Database.Connection.Protocol
    ) async throws -> Identity.Record {
        @Dependency(\.passwordClient) var passwordClient

        let passwordHash = try await passwordClient.hash(password)

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

    /// Creates multiple test identities
    static func createTestIdentities(
        count: Int,
        db: any Database.Connection.Protocol
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
