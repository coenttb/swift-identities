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

                    guard let identity = try await Identity.Record.findByEmail(emailAddress) else {
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

                        // Get the identity
                        guard var identity = try await Identity.Record.findById(resetToken.identityId) else {
                            throw Abort(.internalServerError, reason: "Identity not found")
                        }

                        // Update password and increment session version
                        try await identity.setPassword(newPassword)
                        identity.sessionVersion += 1
                        try await identity.save()

                        // Invalidate the token
                        try await Identity.Authentication.Token.Record.invalidateAllForIdentity(identity.id, type: .passwordReset)

                        let emailAddress = identity.email

                        @Dependency(\.fireAndForget) var fireAndForget
                        await fireAndForget {
                            try await sendPasswordChangeNotification(emailAddress)
                        }

                        logger.notice("Password reset completed", metadata: [
                            "component": "Backend.Password",
                            "operation": "resetConfirm",
                            "identityId": "\(identity.id)"
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

                    // Update password and increment session version
                    try await identity.setPassword(newPassword)
                    identity.sessionVersion += 1
                    try await identity.save()

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
