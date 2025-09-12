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
                    
                    @Dependency(\.defaultDatabase) var db
                    
                    // Single transaction for EVERYTHING including email availability check
                    let tokenValue = try await db.write { db in
                        // 1. Check email availability INSIDE transaction (prevents race conditions)
                        let emailTaken = try await Identity.Record
                            .where { $0.email.eq(newEmailAddress) }
                            .fetchCount(db) > 0
                        
                        if emailTaken {
                            throw Identity.Authentication.ValidationError.invalidInput("Email address is already in use")
                        }
                        
                        // 2. Cancel any pending email change requests
                        try await Identity.Email.Change.Request.Record
                            .where { $0.identityId.eq(identity.id) }
                            .where { request in
                                request.confirmedAt == nil && request.cancelledAt == nil
                            }
                            .update { $0.cancelledAt = Date() }
                            .execute(db)
                        
                        // 3. Delete existing email change tokens
                        try await Identity.Token.Record
                            .delete()
                            .where { $0.identityId.eq(identity.id) }
                            .where { $0.type.eq(Identity.Token.Record.TokenType.emailChange) }
                            .execute(db)
                        
                        @Dependency(\.date) var date
                        
                        
                        let token = try await Identity.Token.Record
                            .insert {
                                Identity.Token.Record.Draft(
                                    identityId: identity.id,
                                    type: .emailChange,
                                    validUntil: date().addingTimeInterval(86400) // 24 hours
                                )
                            }
                            .returning(\.self)
                            .fetchOne(db)!
                        
                        
                        // Use UPSERT to handle multiple change requests gracefully
                        // This ensures only one pending email change request per identity
                        try await Identity.Email.Change.Request.Record
                            .insert {
                                Identity.Email.Change.Request.Record.Draft(
                                    identityId: identity.id,
                                    newEmail: newEmailAddress,
                                    verificationToken: token.value, // Link to token!
                                    requestedAt: date(),
                                    expiresAt: date().addingTimeInterval(86400), // 24 hours
                                    confirmedAt: nil,
                                    cancelledAt: nil
                                )
                            } onConflict: { cols in
                                cols.identityId
                            } doUpdate: { updates, excluded in
                                // Replace the entire request with the new one
                                updates.newEmail = excluded.newEmail
                                updates.verificationToken = excluded.verificationToken
                                updates.requestedAt = excluded.requestedAt
                                updates.expiresAt = excluded.expiresAt
                                updates.confirmedAt = nil  // Reset confirmation
                                updates.cancelledAt = nil  // Reset cancellation
                            }
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
                    
                    // Single transaction with JOIN for optimal performance
                    let result = try await db.write { db in
                        // Single JOIN query to get everything at once
                        let `where` = Identity.Token.Record
                            .where { $0.value.eq(token) }
                            .where { $0.type.eq(Identity.Token.Record.TokenType.emailChange) }
                            .where { $0.validUntil > Date() }
                        
                        let data = `where`
                            .join(Identity.Email.Change.Request.Record.all) { token, request in
                                request.verificationToken.eq(token.value) &&
                                request.identityId.eq(token.identityId) &&
                                request.confirmedAt == nil &&
                                request.cancelledAt == nil &&
                                request.expiresAt > Date()
                            }
                            .join(Identity.Record.all) { token, _, identity in
                                token.identityId.eq(identity.id)
                            }
                            .select { token, request, identity in
                                EmailChangeValidationData.Columns(
                                    token: token,
                                    request: request,
                                    identity: identity
                                )
                            }
                        
                        guard let data = try await data.fetchOne(db) else {
                            throw Identity.Authentication.ValidationError.invalidToken
                        }
                        
                        let newEmailAddress = data.request.newEmail
                        
                        // Check if new email is still available (in same transaction!)
                        let emailTaken = try await Identity.Record
                            .where { $0.email.eq(newEmailAddress) }
                            .where { $0.id.neq(data.identity.id) }
                            .fetchCount(db) > 0
                        
                        if emailTaken {
                            // Cancel the request since email is no longer available
                            try await Identity.Email.Change.Request.Record
                                .where { $0.id.eq(data.request.id) }
                                .update { $0.cancelledAt = date() }
                                .execute(db)
                            
                            throw Identity.Authentication.ValidationError.invalidInput("Email address is already in use")
                        }
                        
                        let oldEmail = data.identity.email
                        let newSessionVersion = data.identity.sessionVersion + 1
                        // Update identity email and session version
                        try await Identity.Record
                            .where { $0.id.eq(data.identity.id) }
                            .update { record in
                                record.email = newEmailAddress
                                record.sessionVersion = record.sessionVersion + 1
                                record.updatedAt = date()
                            }
                            .execute(db)
                        
                        // Mark email change request as confirmed
                        try await Identity.Email.Change.Request.Record
                            .where { $0.id.eq(data.request.id) }
                            .update { request in
                                request.confirmedAt = date()
                            }
                            .execute(db)
                        
                        // 3. DELETE all email change tokens for this identity (cleaner than UPDATE)
                        try await Identity.Token.Record
                            .delete()
                            .where { $0.identityId.eq(data.identity.id) }
                            .where { $0.type.eq(Identity.Token.Record.TokenType.emailChange) }
                            .execute(db)
                        
                        return (
                            identity: data.identity,
                            oldEmail: oldEmail,
                            newEmail: newEmailAddress,
                            newSessionVersion: newSessionVersion
                        )
                    }
                    
                    logger.notice("Email change completed", metadata: [
                        "component": "Backend.Email",
                        "operation": "changeConfirm",
                        "identityId": "\(result.identity.id)",
                        "oldEmailDomain": "\(result.oldEmail.domain)",
                        "newEmailDomain": "\(result.newEmail.domain)"
                    ])
                    
                    @Dependency(\.fireAndForget) var fireAndForget
                    await fireAndForget {
                        do {
                            try await onEmailChangeSuccess(result.oldEmail, result.newEmail)
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
                        result.identity.id,
                        result.newEmail,
                        result.newSessionVersion
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
