import Foundation
import Records
import Dependencies

// MARK: - Database Operations

extension Identity.Authentication.ApiKey.Record {
    
    // REMOVED: Async init that auto-saves to database
    // Create API keys inline within transactions for proper atomicity
}
