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

extension Identity.Standalone.Client.Profile {
    /// Live implementation of the profile client for standalone deployments.
    ///
    /// This implementation directly accesses the database to manage user profiles.
    public static var live: Self {
        Self(
            get: {
                // Get authenticated identity
                let identity = try await Database.Identity.get(by: .auth)
                
                // Get or create profile
                let profile = try await Database.Identity.Profile.getOrCreate(for: identity.id)
                
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
                let identity = try await Database.Identity.get(by: .auth)
                
                // Get or create profile
                var profile = try await Database.Identity.Profile.getOrCreate(for: identity.id)
                
                // Update display name
                try await profile.updateDisplayName(displayName)
            }
        )
    }
}
