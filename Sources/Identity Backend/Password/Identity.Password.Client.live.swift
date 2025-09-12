//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 12/09/2024.
//

import ServerFoundation
import IdentitiesTypes
import Vapor
import Dependencies
import EmailAddress
import Records

extension Identity.Password.Client {
    package static func live(
        sendPasswordResetEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String) async throws -> Void,
        sendPasswordChangeNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.passwordValidation.validate) var validatePassword
        
        return .init(
            reset: .init(
                request: { email in
                    let emailAddress = try EmailAddress(email)

                    @Dependency(\.defaultDatabase) var db
                    guard let identity = try await db.read({ db in
                        try await Identity.Record
                            .where { $0.emailString.eq(emailAddress.rawValue) }
                            .fetchOne(db)
                    }) else {
                        // Don't reveal if email exists or not
                        logger.debug("Password reset requested for non-existent email", metadata: [
                            "component": "Backend.Password",
                            "operation": "resetRequest",
                            "emailDomain": "\(emailAddress.domain)"
                        ])
                        return // Silently succeed to prevent email enumeration
                    }

                    // Invalidate existing reset tokens
                    try await Identity.Authentication.Token.Record.invalidateAllForIdentity(identity.id, type: .passwordReset)

                    // Create new reset token
                    let resetToken = try await Identity.Authentication.Token.Record(
                        identityId: identity.id,
                        type: .passwordReset,
                        validityHours: 1
                    )
                    
                    let tokenValue = resetToken.value

                    @Dependency(\.fireAndForget) var fireAndForget
                    await fireAndForget {
                        try await sendPasswordResetEmail(emailAddress, tokenValue)
                    }

                    logger.info("Password reset email sent", metadata: [
                        "component": "Backend.Password",
                        "operation": "resetRequest",
                        "identityId": "\(identity.id)"
                    ])
                },
                confirm: { token, newPassword in
                    do {
                        let _ = try validatePassword(newPassword)

                        // Find and validate token
                        guard let resetToken = try await Identity.Authentication.Token.Record.findValid(value: token, type: .passwordReset) else {
                            throw Identity.Authentication.ValidationError.invalidToken
                        }

                        @Dependency(\.defaultDatabase) var db
                        @Dependency(\.date) var date
                        
                        // Perform all updates within a transaction for atomicity
                        let emailAddress = try await db.write { db in
                            // Get the identity within transaction
                            guard var identity = try await Identity.Record
                                .where ({ $0.id.eq(resetToken.identityId) })
                                .fetchOne(db)
                            else {
                                throw Abort(.internalServerError, reason: "Identity not found")
                            }

                            // Update password and increment session version atomically
                            try await identity.setPassword(newPassword)
                            
                            try await Identity.Record.updatePasswordAndInvalidateSessions(
                                id: identity.id,
                                newPasswordHash: identity.passwordHash
                            )

                            // Invalidate all password reset tokens for this identity
                            try await Identity.Authentication.Token.Record
                                .where { 
                                    $0.identityId.eq(identity.id)
                                        .and($0.type.eq(Identity.Authentication.Token.Record.TokenType.passwordReset))
                                }
                                .update { token in
                                    token.validUntil = date() // Set to now to invalidate
                                }
                                .execute(db)
                            
                            return identity.email
                        }

                        @Dependency(\.fireAndForget) var fireAndForget
                        await fireAndForget {
                            try await sendPasswordChangeNotification(emailAddress)
                        }

                        logger.notice("Password reset completed", metadata: [
                            "component": "Backend.Password",
                            "operation": "resetConfirm",
                            "identityId": "\(resetToken.identityId)"
                        ])

                    } catch {
                        logger.error("Password reset failed", metadata: [
                            "component": "Backend.Password",
                            "operation": "resetConfirm",
                            "error": "\(error)"
                        ])
                        throw error
                    }
                }
            ),
            change: .init(
                request: { currentPassword, newPassword in
                    var identity = try await Identity.Record.get(by: .auth)

                    guard try await identity.verifyPassword(currentPassword) else {
                        throw Identity.Authentication.Error.invalidCredentials
                    }

                    _ = try validatePassword(newPassword)

                    // Update password and increment session version atomically
                    try await identity.setPassword(newPassword)
                    
                    try await Identity.Record.updatePasswordAndInvalidateSessions(
                        id: identity.id,
                        newPasswordHash: identity.passwordHash
                    )

                    let emailAddress = identity.email
                    
                    @Dependency(\.fireAndForget) var fireAndForget
                    await fireAndForget {
                        try await sendPasswordChangeNotification(emailAddress)
                    }

                    logger.notice("Password changed", metadata: [
                        "component": "Backend.Password",
                        "operation": "change",
                        "identityId": "\(identity.id)"
                    ])
                }
            )
        )
    }
}
