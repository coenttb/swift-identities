//
//  Identity.Profile+Queries.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import Records
import Dependencies

// MARK: - Database Operations

extension Identity.Profile.Record {
    
    // REMOVED: Async init that auto-saves to database
    // REMOVED: getByIdentity() - Use explicit queries at call sites
    // REMOVED: getOrCreate() - Use UPSERT pattern instead
    // REMOVED: updateDisplayName() - Make DB updates explicit at call sites
    
}
