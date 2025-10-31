import Dependencies
import Foundation
import Identity_Backend
import Records
import RecordsTestSupport

extension Database {
    /// Creates a test database with Identity schema
    static func withIdentitySchema() async throws -> TestDatabase {
        let db = try await Database.testDatabase(prefix: "identity_test")

        // Run all Identity migrations
        let migrator = Identity.Backend.migrator()
        try await migrator.migrate(db)

        return db
    }

    /// Setup mode with Identity schema
    static let withIdentityData = TestDatabaseSetupMode { db in
        let migrator = Identity.Backend.migrator()
        try await migrator.migrate(db)
    }
}
