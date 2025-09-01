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

extension Identity.Backend.Client.Email {
    package static func live(
        sendEmailChangeConfirmation: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress, _ token: String) async throws -> Void,
        sendEmailChangeRequestNotification: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void,
        onEmailChangeSuccess: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.tokenClient) var tokenClient

        return .init(
            change: .init(
                request: { newEmail in
                    do {
                        @Dependency(\.request) var request
                        guard let request else { throw Abort.requestUnavailable }
                        
                        // Check for reauthorization token in headers or cookies
                        let token = request.headers.reauthorizationToken?.token ?? request.cookies["reauthorization_token"]?.string
                        
                        guard let token else {
                            return .requiresReauthentication
                        }
                        
                        do {
                            _ = try await tokenClient.verifyReauthorization(token)
                        } catch {
                            return .requiresReauthentication
                        }

                        let identity = try await Database.Identity.get(by: .auth)
                        let newEmailAddress = try EmailAddress(newEmail)

                        // Check if new email is already in use
                        if try await Database.Identity.findByEmail(newEmailAddress) != nil {
                            throw Identity.Backend.ValidationError.invalidInput("Email address is already in use")
                        }

                        // Invalidate existing email change tokens
                        try await Database.Identity.Token.invalidateAllForIdentity(identity.id, type: .emailChange)

                        // Create new email change token
                        let changeToken = try await Database.Identity.Token(
                            identityId: identity.id,
                            type: .emailChange,
                            validityHours: 24 // 24 hours
                        )

                        // Create email change request
                        let emailChangeRequest = try await Database.Identity.Email.Change.Request(
                            identityId: identity.id,
                            newEmail: newEmailAddress
                        )
                        
                        let tokenValue = changeToken.value

                        @Dependency(\.fireAndForget) var fireAndForget

                        await fireAndForget {
                            try await sendEmailChangeConfirmation(
                                identity.email,
                                newEmailAddress,
                                tokenValue
                            )
                            
                            logger.debug("Email change confirmation sent", metadata: [
                                "component": "Backend.Email",
                                "operation": "changeRequest",
                                "identityId": "\(identity.id)"
                            ])
                        }

                        await fireAndForget {
                            try await sendEmailChangeRequestNotification(
                                identity.email,
                                newEmailAddress
                            )

                            logger.debug("Email change notification sent", metadata: [
                                "component": "Backend.Email",
                                "operation": "changeNotification",
                                "identityId": "\(identity.id)"
                            ])
                        }

                        return .success
                    } catch {
                        logger.error("Email change request failed", metadata: [
                            "component": "Backend.Email",
                            "operation": "changeRequest",
                            "error": "\(error)"
                        ])
                        throw error
                    }
                },
                confirm: { token in
                    do {
                        // Find valid email change token
                        guard try await Database.Identity.Token.findValid(value: token, type: .emailChange) != nil else {
                            throw Identity.Backend.ValidationError.invalidToken
                        }

                        // Find email change request by token
                        guard let emailChangeRequest = try await Database.Identity.Email.Change.Request.findByToken(token) else {
                            throw Abort(.notFound, reason: "Email change request not found")
                        }

                        // Get the identity
                        guard var identity = try await Database.Identity.findById(emailChangeRequest.identityId) else {
                            throw Abort(.internalServerError, reason: "Identity not found")
                        }

                        let newEmailAddress = try EmailAddress(emailChangeRequest.newEmail)

                        // Double-check new email is still available
                        if let existingIdentity = try await Database.Identity.findByEmail(newEmailAddress),
                           existingIdentity.id != identity.id {
                            throw Identity.Backend.ValidationError.invalidInput("Email address is already in use")
                        }

                        let oldEmail = identity.email

                        // Update identity with new email
                        identity.email = newEmailAddress
                        identity.sessionVersion += 1
                        try await identity.save()

                        // Confirm the email change request
                        var mutableRequest = emailChangeRequest
                        _ = try await mutableRequest.confirm()
                        
                        // Invalidate all email change tokens for this identity
                        try await Database.Identity.Token.invalidateAllForIdentity(identity.id, type: .emailChange)

                        logger.notice("Email change completed", metadata: [
                            "component": "Backend.Email",
                            "operation": "changeConfirm",
                            "identityId": "\(identity.id)",
                            "oldEmailDomain": "\(oldEmail.domain)",
                            "newEmailDomain": "\(newEmailAddress.domain)"
                        ])

                        @Dependency(\.fireAndForget) var fireAndForget
                        await fireAndForget {
                            do {
                                try await onEmailChangeSuccess(oldEmail, newEmailAddress)
                            } catch {
                                logger.error("Post-email change operation failed", metadata: [
                                    "component": "Backend.Email",
                                    "operation": "postChangeCallback",
                                    "error": "\(error)"
                                ])
                            }
                        }

                        // Generate new tokens for the updated identity  
                        let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
                            identity.id,
                            identity.email,
                            identity.sessionVersion
                        )
                        
                        let response = Identity.Authentication.Response(
                            accessToken: accessToken,
                            refreshToken: refreshToken
                        )
                        
                        return response
                    } catch {
                        logger.error("Email change confirm failed", metadata: [
                            "component": "Backend.Email",
                            "operation": "changeConfirm",
                            "error": "\(error)"
                        ])
                        throw error
                    }
                }
            )
        )
    }
}
