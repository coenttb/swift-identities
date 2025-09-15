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

extension Identity.Password.Reset.Client {
    package static func live(
        sendPasswordResetEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String) async throws -> Void,
        sendPasswordChangeNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.passwordValidation.validate) var validatePassword
        
        return .init(
            request: { email in
                let emailAddress = try EmailAddress(email)

                @Dependency(\.defaultDatabase) var db
                guard let identity = try await db.read({ db in
                    try await Identity.Record
                        .where { $0.email.eq(emailAddress) }
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

                // Single transaction for token invalidation and creation
                let tokenValue: String = try await db.write { db in
                    // Invalidate existing reset tokens
                    try await Identity.Token.Record
                        .delete()
                        .where { $0.identityId.eq(identity.id) }
                        .where { $0.type.eq(Identity.Token.Record.TokenType.passwordReset) }
                        .execute(db)
                    
                    @Dependency(\.date) var date
                    
                    // Create new reset token
                    
                    // Use UPSERT to handle multiple reset requests gracefully
                    // This ensures only one password reset token per identity
                    let token = try await Identity.Token.Record
                        .insert {
                            Identity.Token.Record.Draft(
                                identityId: identity.id,
                                type: .passwordReset,
                                validUntil: date().addingTimeInterval(3600) // 1 hour
                            )
                        } onConflict: { cols in
                            (cols.identityId, cols.type)
                        } doUpdate: { updates, excluded in
                            // Replace the token completely with new one
                            updates.value = excluded.value
                            updates.validUntil = excluded.validUntil
                            updates.createdAt = excluded.createdAt
                            updates.lastUsedAt = nil  // Reset usage
                        }
                        .returning(\.self)
                        .fetchOne(db)
                    
                    guard let value = token?.value else { fatalError() }

                    return value
                }

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

                    @Dependency(\.defaultDatabase) var db
                    @Dependency(\.date) var date
                    
                    // Single transaction with JOIN for optimal performance
                    let (emailAddress, identityId) = try await db.write { db in
                        // Find token and identity in single JOIN query
                        let data = try await Identity.Token.Record
                            .where { $0.value.eq(token) }
                            .where { $0.type.eq(Identity.Token.Record.TokenType.passwordReset) }
                            .where { $0.validUntil > Date() }
                            .join(Identity.Record.all) { token, identity in
                                token.identityId.eq(identity.id)
                            }
                            .select { token, identity in
                                PasswordResetData.Columns(
                                    token: token,
                                    identity: identity
                                )
                            }
                            .fetchOne(db)
                        
                        guard let data else {
                            throw Identity.Authentication.ValidationError.invalidToken
                        }
                        
                        // Hash the new password
                        @Dependency(\.envVars) var envVars
                        @Dependency(\.application) var application
                        
                        let passwordHash: String = try await application.threadPool.runIfActive {
                            try Bcrypt.hash(newPassword, cost: envVars.bcryptCost)
                        }
                        
                        // Update password and increment session version atomically
                        try await Identity.Record
                            .where { $0.id.eq(data.identity.id) }
                            .update { identity in
                                identity.passwordHash = passwordHash
                                identity.sessionVersion = identity.sessionVersion + 1
                                identity.updatedAt = date()
                            }
                            .execute(db)
                        
                        // DELETE all password reset tokens for this identity (cleaner than UPDATE)
                        try await Identity.Token.Record
                            .delete()
                            .where { $0.identityId.eq(data.identity.id) }
                            .where { $0.type.eq(Identity.Token.Record.TokenType.passwordReset) }
                            .execute(db)
                        
                        return (data.identity.email, data.identity.id)
                    }

                    @Dependency(\.fireAndForget) var fireAndForget
                    await fireAndForget {
                        try await sendPasswordChangeNotification(emailAddress)
                    }

                    logger.notice("Password reset completed", metadata: [
                        "component": "Backend.Password",
                        "operation": "resetConfirm",
                        "identityId": "\(identityId)"
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
        )
    }
}

@Selection
struct PasswordResetData: Sendable {
    let token: Identity.Token.Record
    let identity: Identity.Record
}
