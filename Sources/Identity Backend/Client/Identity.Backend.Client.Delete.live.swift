//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 01/02/2025.
//

import ServerFoundation
import IdentitiesTypes
import Vapor
import Dependencies
import EmailAddress

extension Identity.Backend.Client.Delete {
    package static func live(
        sendDeletionRequestNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
        sendDeletionConfirmationNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.tokenClient) var tokenClient

        return .init(
            request: { reauthToken in
                // Verify reauthorization token
                let reauthorizationToken = try await tokenClient.verifyReauthorization(reauthToken)
                
                let identity = try await Database.Identity.get(by: .auth)
                
                // Verify token belongs to this identity
                guard reauthorizationToken.identityId == identity.id else {
                    throw Abort(.unauthorized, reason: "Invalid reauthorization token")
                }
                
                // Check for existing deletion (pending or cancelled)
                @Dependency(\.defaultDatabase) var db
                let existingDeletions = try await db.read { db in
                    try await Database.Identity.Deletion.findByIdentity(identity.id).fetchAll(db)
                }
                if let existingDeletion = existingDeletions.first {
                    if existingDeletion.status == .pending {
                        throw Abort(.badRequest, reason: "User is already pending deletion")
                    } else if existingDeletion.status == .cancelled {
                        // Reactivate the cancelled deletion
                        @Dependency(\.date) var date
                        @Dependency(\.calendar) var calendar
                        
                        let now = date()
                        let scheduledFor = calendar.date(byAdding: .day, value: 7, to: now) ?? now
                        
                        try await db.write { db in
                            try await Database.Identity.Deletion
                                .update { deletion in
                                    deletion.requestedAt = now
                                    deletion.cancelledAt = nil
                                    deletion.scheduledFor = scheduledFor
                                }
                                .where { $0.id.eq(existingDeletion.id) }
                                .execute(db)
                        }
                    }
                } else {
                    // Create new deletion request
                    _ = try await Database.Identity.Deletion(
                        identityId: identity.id,
                        reason: nil,
                        gracePeriodDays: 7
                    )
                }
                
                // Invalidate the reauthorization token
                try await Database.Identity.Token.invalidateAllForIdentity(identity.id, type: .reauthenticationToken)
                
                logger.notice("Deletion requested", metadata: [
                    "component": "Backend.Delete",
                    "operation": "request",
                    "identityId": "\(identity.id)"
                ])

                @Dependency(\.fireAndForget) var fireAndForget
                await fireAndForget {
                    try await sendDeletionRequestNotification(identity.email)
                }
            },
            cancel: {
                let identity = try await Database.Identity.get(by: .auth)
                
                // Find pending deletion request
                guard let deletion = try await Database.Identity.Deletion.findPendingForIdentity(identity.id),
                      deletion.status == .pending else {
                    throw Abort(.badRequest, reason: "User is not pending deletion")
                }
                
                // Cancel the deletion request
                var mutableDeletion = deletion
                try await mutableDeletion.cancel()
                
                logger.info("Deletion cancelled", metadata: [
                    "component": "Backend.Delete",
                    "operation": "cancel",
                    "identityId": "\(identity.id)"
                ])
            },
            confirm: {
                let identity = try await Database.Identity.get(by: .auth)
                
                // Find pending deletion request
                guard let deletion = try await Database.Identity.Deletion.findPendingForIdentity(identity.id),
                      deletion.status == .pending else {
                    throw Abort(.badRequest, reason: "User is not pending deletion")
                }
                
                @Dependency(\.date) var date
                
                // Check grace period has expired
                let currentDate = date()
                
                guard currentDate >= deletion.scheduledFor else {
                    let remainingTime = deletion.scheduledFor.timeIntervalSince(currentDate)
                    let secondsPerDay = TimeInterval(24 * 60 * 60)
                    let remainingDays = Int(ceil(remainingTime / secondsPerDay))
                    throw Abort(.badRequest, reason: "Grace period has not yet expired. \(remainingDays) days remaining.")
                }
                
                // Confirm the deletion
                var mutableDeletion = deletion
                try await mutableDeletion.confirm()
                
                // Actually delete the identity
                try await Database.Identity.delete(id: identity.id)
                
                logger.notice("Identity deleted", metadata: [
                    "component": "Backend.Delete",
                    "operation": "confirm",
                    "identityId": "\(identity.id)"
                ])
                
                @Dependency(\.fireAndForget) var fireAndForget
                await fireAndForget {
                    try await sendDeletionConfirmationNotification(identity.email)
                }
            }
        )
    }
}
