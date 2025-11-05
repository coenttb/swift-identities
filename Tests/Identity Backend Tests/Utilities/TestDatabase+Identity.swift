import Dependencies
import Foundation
import Identity_Backend
import Records
import RecordsTestSupport

extension Database.TestDatabaseSetupMode {
    /// Identity schema setup mode
    static let withIdentitySchema = Database.TestDatabaseSetupMode { db in
        // Run all Identity migrations
        let migrator = Identity.Backend.migrator()
        try await migrator.migrate(db)
    }
}

extension Database.TestDatabase {
    /// Creates a test database with Identity schema
    static func withIdentitySchema() -> LazyTestDatabase {
        LazyTestDatabase(setupMode: .withIdentitySchema)
    }
}
