//
//  Identity.Standalone.Client.Profile.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import Dependencies
import DependenciesMacros
import IdentitiesTypes

extension Identity.Standalone.Client {
    /// Profile management client for standalone deployments.
    ///
    /// Provides methods to get and update user profiles with display name management.
    public struct Profile: Sendable {
        /// Retrieves the current user's profile
        @DependencyEndpoint
        public var get: @Sendable () async throws -> Identity.API.Profile.Response
        
        /// Updates the display name for the current user
        @DependencyEndpoint
        public var updateDisplayName: @Sendable (_ displayName: String?) async throws -> Void
        
        public init(
            get: @Sendable @escaping () async throws -> Identity.API.Profile.Response = unimplemented("Identity.Standalone.Client.Profile.get"),
            updateDisplayName: @Sendable @escaping (_ displayName: String?) async throws -> Void = unimplemented("Identity.Standalone.Client.Profile.updateDisplayName")
        ) {
            self.get = get
            self.updateDisplayName = updateDisplayName
        }
    }
}
