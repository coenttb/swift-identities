//
//  Identity.Backend.Client.Delete.Extension.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/09/2024.
//

import Foundation
import IdentitiesTypes
import ServerFoundation

extension Identity.Client.Delete {
    /// Represents the current status of an identity deletion request.
    ///
    /// This struct provides information about pending deletion requests,
    /// including the current status and time remaining before deletion.
    package struct DeletionStatus: Codable, Hashable, Sendable {
        /// The current status of the deletion request
        package enum Status: String, Codable, Sendable {
            case pending
            case awaitingGracePeriod
            case readyForDeletion
            case cancelled
        }
        
        /// The current status of the deletion
        package let status: Status
        
        /// Number of days remaining until deletion (nil if not applicable)
        package let daysRemaining: Int?
        
        /// Creates a new deletion status
        package init(status: Status, daysRemaining: Int? = nil) {
            self.status = status
            self.daysRemaining = daysRemaining
        }
    }
    
    /// Checks the current deletion status for the authenticated identity.
    ///
    /// This method queries the current deletion status without requiring an API call.
    /// 
    /// - Returns: A `DeletionStatus` if a deletion is pending, or `nil` if no deletion request exists
    package func status() async throws -> DeletionStatus? {
        let identity = try await Database.Identity.get(by: .auth)
        
        // Check for pending deletion
        guard let deletion = try await Database.Identity.Deletion.findPendingForIdentity(identity.id) else {
            return nil
        }
        
        // Map database status to client status
        let clientStatus: DeletionStatus.Status
        switch deletion.status {
        case .pending, .awaitingGracePeriod:
            clientStatus = .pending
        case .readyForDeletion:
            clientStatus = .readyForDeletion
        case .cancelled:
            clientStatus = .cancelled
        case .confirmed:
            // Shouldn't happen but handle it
            clientStatus = .awaitingGracePeriod
        }
        
        return DeletionStatus(
            status: clientStatus,
            daysRemaining: deletion.daysUntilDeletion
        )
    }
}