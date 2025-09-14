//
//  Identity.Standalone.Client.Profile.live.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import Identity_Backend
import Dependencies
import IdentitiesTypes
import Records

extension Identity.Standalone.Client.Profile {
    /// Live implementation of the profile client for standalone deployments.
    ///
    /// This implementation directly accesses the database to manage user profiles.
    public static var live: Self {
        Self(
            get: {
                // Get authenticated identity
                let identity = try await Identity.Record.get(by: .auth)
                
                @Dependency(\.defaultDatabase) var db
                @Dependency(\.uuid) var uuid
                @Dependency(\.date) var date
                
                // Upsert to ensure profile exists, then fetch it
                let profile = try await db.write { db in
                    // Create default profile if doesn't exist
                    let defaultProfile = Identity.Profile.Record.Draft(
                        id: uuid(),
                        identityId: identity.id,
                        displayName: nil,
                        createdAt: date(),
                        updatedAt: date()
                    )
                    
                    try await Identity.Profile.Record
                        .upsertByIdentityId(defaultProfile)
                        .execute(db)
                    
                    // Fetch the profile (guaranteed to exist now)
                    return try await Identity.Profile.Record
                        .findByIdentity(identity.id)
                        .fetchOne(db)!
                }
                
                return Identity.API.Profile.Response(
                    id: profile.id,
                    identityId: profile.identityId,
                    displayName: profile.displayName,
                    email: identity.email,
                    createdAt: profile.createdAt,
                    updatedAt: profile.updatedAt
                )
            },
            updateDisplayName: { displayName in
                // Get authenticated identity
                let identity = try await Identity.Record.get(by: .auth)
                
                @Dependency(\.defaultDatabase) var db
                @Dependency(\.uuid) var uuid
                @Dependency(\.date) var date
                
                // Validate display name if provided
                if let displayName = displayName {
                    try Identity.Profile.Record.validateDisplayName(displayName)
                }
                
                // Atomic upsert - creates if doesn't exist, updates if it does
                try await db.write { db in
                    let profile = Identity.Profile.Record(
                        id: uuid(),
                        identityId: identity.id,
                        displayName: displayName,
                        createdAt: date(),
                        updatedAt: date()
                    )
                    
                    try await Identity.Profile.Record
                        .upsertByIdentityId(profile)
                        .execute(db)
                }
            }
        )
    }
}
