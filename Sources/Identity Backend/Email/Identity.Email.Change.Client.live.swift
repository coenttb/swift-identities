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

extension Identity.Email.Change.Client {
    package static func live(
        sendEmailChangeConfirmation: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress, _ token: String) async throws -> Void,
        sendEmailChangeRequestNotification: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void,
        onEmailChangeSuccess: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.tokenClient) var tokenClient

        return .init(
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

                        let identity = try await Identity.Record.get(by: .auth)
                        let newEmailAddress = try EmailAddress(newEmail)

                        // Check if new email is already in use
                        @Dependency(\.defaultDatabase) var db
                        let existingIdentity = try await db.read { db in
                            try await Identity.Record
                                .where { $0.emailString.eq(newEmailAddress.rawValue) }
                                .fetchOne(db)
                        }
                        if existingIdentity != nil {
                            throw Identity.Authentication.ValidationError.invalidInput("Email address is already in use")
                        }

                        // Single transaction for token and request creation
                        let tokenValue = try await db.write { db in
                            // Invalidate existing email change tokens
                            try await Identity.Token.Record
                                .delete()
                                .where { $0.identityId.eq(identity.id) }
                                .where { $0.type.eq(Identity.Token.Record.TokenType.emailChange) }
                                .execute(db)
                            
                            @Dependency(\.uuid) var uuid
                            @Dependency(\.date) var date
                            
                            // Create new token
                            let token = Identity.Token.Record(
                                id: uuid(),
                                identityId: identity.id,
                                type: .emailChange,
                                validUntil: date().addingTimeInterval(86400) // 24 hours
                            )
                            
                            try await Identity.Token.Record
                                .insert { token }
                                .execute(db)
                            
                            // Create email change request linked to token
                            let request = Identity.Email.Change.Request.Record(
                                id: uuid(),
                                identityId: identity.id,
                                newEmail: newEmailAddress.rawValue,
                                verificationToken: token.value, // Link to token!
                                requestedAt: date(),
                                expiresAt: date().addingTimeInterval(86400), // 24 hours
                                confirmedAt: nil,
                                cancelledAt: nil
                            )
                            
                            try await Identity.Email.Change.Request.Record
                                .insert { request }
                                .execute(db)
                            
                            return token.value
                        }

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
                        @Dependency(\.defaultDatabase) var db
                        @Dependency(\.date) var date
                        
                        // Single transaction for all reads and initial validation
                        let validationData = try await db.read { db in
                            // 1. Validate token and get it
                            let authToken = try await Identity.Token.Record
                                .where { $0.value.eq(token) }
                                .where { $0.type.eq(Identity.Token.Record.TokenType.emailChange) }
                                .where { #sql("\($0.validUntil) > CURRENT_TIMESTAMP") }
                                .fetchOne(db)
                            
                            guard let authToken else {
                                throw Identity.Authentication.ValidationError.invalidToken
                            }
                            
                            // 2. Get email change request
                            let emailChangeRequest = try await Identity.Email.Change.Request.Record
                                .where { $0.verificationToken.eq(token) }
                                .where { request in
                                    #sql("\(request.confirmedAt) IS NULL") &&
                                    #sql("\(request.cancelledAt) IS NULL") &&
                                    #sql("\(request.expiresAt) > CURRENT_TIMESTAMP")
                                }
                                .fetchOne(db)
                            
                            guard let emailChangeRequest else {
                                throw Abort(.notFound, reason: "Email change request not found or expired")
                            }
                            
                            // 3. Get the identity
                            let identity = try await Identity.Record
                                .where { $0.id.eq(emailChangeRequest.identityId) }
                                .fetchOne(db)
                            
                            guard let identity else {
                                throw Abort(.internalServerError, reason: "Identity not found")
                            }
                            
                            let newEmailAddress = try EmailAddress(emailChangeRequest.newEmail)
                            
                            // 4. Check if new email is available
                            let existingIdentity = try await Identity.Record
                                .where { $0.emailString.eq(newEmailAddress.rawValue) }
                                .fetchOne(db)
                            
                            if let existingIdentity, existingIdentity.id != identity.id {
                                throw Identity.Authentication.ValidationError.invalidInput("Email address is already in use")
                            }
                            
                            return (
                                authToken: authToken,
                                emailChangeRequest: emailChangeRequest,
                                identity: identity,
                                newEmailAddress: newEmailAddress
                            )
                        }
                        
                        let oldEmail = validationData.identity.email
                        let newEmailAddress = validationData.newEmailAddress
                        let newSessionVersion = validationData.identity.sessionVersion + 1
                        
                        // Single write transaction for all updates
                        try await db.write { db in
                            let now = date()
                            
                            // 1. Update identity
                            try await Identity.Record
                                .where { $0.id.eq(validationData.identity.id) }
                                .update { record in
                                    record.emailString = newEmailAddress.rawValue
                                    record.sessionVersion = record.sessionVersion + 1
                                    record.updatedAt = now
                                }
                                .execute(db)
                            
                            // 2. Mark email change request as confirmed
                            try await Identity.Email.Change.Request.Record
                                .where { $0.id.eq(validationData.emailChangeRequest.id) }
                                .update { request in
                                    request.confirmedAt = now
                                }
                                .execute(db)
                            
                            // 3. Invalidate all email change tokens for this identity
                            try await Identity.Token.Record
                                .where { $0.identityId.eq(validationData.identity.id) }
                                .where { $0.type.eq(Identity.Token.Record.TokenType.emailChange) }
                                .update { token in
                                    token.validUntil = now  // Set to now to invalidate
                                }
                                .execute(db)
                        }
                        
                        logger.notice("Email change completed", metadata: [
                            "component": "Backend.Email",
                            "operation": "changeConfirm",
                            "identityId": "\(validationData.identity.id)",
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
                        
                        // Generate new tokens with updated session version
                        let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
                            validationData.identity.id,
                            newEmailAddress,
                            newSessionVersion
                        )
                        
                        return Identity.Authentication.Response(
                            accessToken: accessToken,
                            refreshToken: refreshToken
                        )
                        
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
    }
}
