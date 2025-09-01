//
//  Identity.API.Profile.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import CasePaths
import Foundation
import ServerFoundation
import IdentitiesTypes

extension Identity.API {
    /// Profile management endpoints for standalone identity deployments.
    ///
    /// These endpoints are only available in Standalone mode and provide
    /// username and profile management capabilities beyond the core identity system.
    @CasePathable
    @dynamicMemberLookup
    public enum Profile: Equatable, Sendable {
        /// Retrieves the current user's profile
        case get
        
        /// Updates the display name for the current user
        case updateDisplayName(Identity.API.Profile.UpdateDisplayName)
    }
}

extension Identity.API.Profile {
    /// Request to update the display name
    public struct UpdateDisplayName: Codable, Equatable, Sendable {
        public let displayName: String?
        
        public enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
        
        public init(displayName: String?) {
            self.displayName = displayName
        }
    }
    
    
    /// Response containing profile information
    public struct Response: Codable, Equatable, Sendable {
        public let id: UUID
        public let identityId: UUID
        public let displayName: String?
        public let email: EmailAddress
        public let createdAt: Date
        public let updatedAt: Date
        
        public init(
            id: UUID,
            identityId: UUID,
            displayName: String?,
            email: EmailAddress,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.identityId = identityId
            self.displayName = displayName
            self.email = email
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

extension Identity.API.Profile {
    /// Router for profile management endpoints.
    public struct Router: ParserPrinter, Sendable {
        
        public init() {}
        
        public var body: some URLRouting.Router<Identity.API.Profile> {
            OneOf {
                URLRouting.Route(.case(Identity.API.Profile.get)) {
                    Method.get
                }
                
                URLRouting.Route(.case(Identity.API.Profile.updateDisplayName)) {
                    Path { "display-name" }
                    Method.post
                    Body(.form(Identity.API.Profile.UpdateDisplayName.self, decoder: .identities))
                }
            }
        }
    }
}
