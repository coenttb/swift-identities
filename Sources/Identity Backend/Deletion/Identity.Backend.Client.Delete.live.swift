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

extension Identity.Deletion.Client {
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
                
                let identity = try await Identity.Record.get(by: .auth)
                
                // Verify token belongs to this identity
                guard reauthorizationToken.identityId == identity.id else {
                    throw Abort(.unauthorized, reason: "Invalid reauthorization token")
                }
                
                // Single transaction for all deletion operations
                @Dependency(\.defaultDatabase) var db
                try await db.write { db in
                    // Check for existing deletion
                    let existingDeletion = try await Identity.Deletion.Record
                        .findByIdentity(identity.id)
                        .fetchOne(db)
                    
                    if let existingDeletion = existingDeletion {
                        if existingDeletion.status == .pending {
                            throw Abort(.badRequest, reason: "User is already pending deletion")
                        } else if existingDeletion.status == .cancelled {
                            // Reactivate the cancelled deletion
                            @Dependency(\.date) var date
                            @Dependency(\.calendar) var calendar
                            
                            let now = date()
                            let scheduledFor = calendar.date(byAdding: .day, value: 7, to: now) ?? now
                            
                            try await Identity.Deletion.Record
                                .update { deletion in
                                    deletion.requestedAt = now
                                    deletion.cancelledAt = nil
                                    deletion.scheduledFor = scheduledFor
                                }
                                .where { $0.id.eq(existingDeletion.id) }
                                .execute(db)
                        }
                    } else {
                                               
                        // Use UPSERT to handle multiple deletion requests gracefully
                        // This ensures only one deletion request per identity
                        try await Identity.Deletion.Record
                            .insert {
                                Identity.Deletion.Record.Draft(
                                    identityId: identity.id,
                                    reason: nil,
                                    gracePeriodDays: 7
                                )
                            } onConflict: { cols in
                                cols.identityId
                            } doUpdate: { updates, excluded in
                                // Replace the entire deletion request with the new one
                                updates.requestedAt = excluded.requestedAt
                                updates.reason = excluded.reason
                                updates.scheduledFor = excluded.scheduledFor
                                updates.confirmedAt = nil  // Reset confirmation
                                updates.cancelledAt = nil  // Reset cancellation
                            }
                            .execute(db)
                    }
                    
                    // Invalidate the reauthorization token
                    try await Identity.Token.Record
                        .delete()
                        .where { $0.identityId.eq(identity.id) }
                        .where { $0.type.eq(Identity.Token.Record.TokenType.reauthentication) }
                        .execute(db)
                }
                
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
                let identity = try await Identity.Record.get(by: .auth)
                
                @Dependency(\.defaultDatabase) var db
                @Dependency(\.date) var date
                
                // Find and cancel in single transaction
                try await db.write { db in
                    // Find pending deletion
                    guard let deletion = try await Identity.Deletion.Record
                        .findByIdentity(identity.id)
                        .pending
                        .fetchOne(db),
                          deletion.status == .pending else {
                        throw Abort(.badRequest, reason: "User is not pending deletion")
                    }
                    
                    // Cancel the deletion request
                    try await Identity.Deletion.Record
                        .update { del in
                            del.cancelledAt = date()
                        }
                        .where { $0.id.eq(deletion.id) }
                        .execute(db)
                }
                
                logger.info("Deletion cancelled", metadata: [
                    "component": "Backend.Delete",
                    "operation": "cancel",
                    "identityId": "\(identity.id)"
                ])
            },
            confirm: {
                let identity = try await Identity.Record.get(by: .auth)
                
                @Dependency(\.defaultDatabase) var db
                @Dependency(\.date) var date
                
                // Single transaction for confirmation and deletion
                try await db.write { db in
                    // Find pending deletion request
                    guard let deletion = try await Identity.Deletion.Record
                        .findByIdentity(identity.id)
                        .pending
                        .fetchOne(db),
                          deletion.status == .pending else {
                        throw Abort(.badRequest, reason: "User is not pending deletion")
                    }
                    
                    // Check grace period has expired
                    let currentDate = date()
                    
                    guard currentDate >= deletion.scheduledFor else {
                        let remainingTime = deletion.scheduledFor.timeIntervalSince(currentDate)
                        let secondsPerDay = TimeInterval(24 * 60 * 60)
                        let remainingDays = Int(ceil(remainingTime / secondsPerDay))
                        throw Abort(.badRequest, reason: "Grace period has not yet expired. \(remainingDays) days remaining.")
                    }
                    
                    // Confirm the deletion
                    try await Identity.Deletion.Record
                        .update { del in
                            del.confirmedAt = currentDate
                        }
                        .where { $0.id.eq(deletion.id) }
                        .execute(db)
                    
                    // Actually delete the identity
                    try await Identity.Record
                        .where { $0.id.eq(identity.id) }
                        .delete()
                        .execute(db)
                }
                
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
