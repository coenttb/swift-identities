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
import Records

@Selection
struct EmailVerificationData: Sendable {
    let token: Identity.Token.Record
    let identity: Identity.Record
}

extension Identity.Creation.Client {
    package static func live(
        sendVerificationEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String) async throws -> Void,
        onIdentityCreationSuccess: @escaping @Sendable (_ identity: (id: Identity.ID, email: EmailAddress)) async throws -> Void
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.passwordValidation.validate) var validatePassword

        return .init(
            request: { email, password in
                do {
                    _ = try validatePassword(password)
                    let emailAddress = try EmailAddress(email)

                    @Dependency(\.uuid) var uuid
                    @Dependency(\.date) var date
                    @Dependency(\.envVars) var envVars
                    @Dependency(\.application) var application
                    @Dependency(\.defaultDatabase) var db
                    
                    let passwordHash: String = try await application.threadPool.runIfActive {
                        try Bcrypt.hash(password, cost: envVars.bcryptCost)
                    }
                    
                    // Single transaction for EVERYTHING
                    let (identity, tokenValue) = try await db.write { db in
                        // Check if email already exists INSIDE transaction
                        let existingIdentity = try await Identity.Record
                            .where { $0.emailString.eq(emailAddress.rawValue) }
                            .fetchOne(db)
                        
                        guard existingIdentity == nil else {
                            throw Identity.Authentication.ValidationError.invalidInput("Email already in use")
                        }
                        
                        // Create and insert identity
                        let identity = Identity.Record(
                            id: .init(uuid()),
                            email: emailAddress,
                            passwordHash: passwordHash,
                            emailVerificationStatus: .unverified,
                            sessionVersion: 0,
                            createdAt: date(),
                            updatedAt: date(),
                            lastLoginAt: nil
                        )
                        
                        try await Identity.Record
                            .insert { identity }
                            .execute(db)
                        
                        // Create verification token
                        let token = Identity.Token.Record(
                            id: uuid(),
                            identityId: identity.id,
                            type: .emailVerification,
                            validUntil: date().addingTimeInterval(86400) // 24 hours
                        )
                        
                        try await Identity.Token.Record
                            .insert { token }
                            .execute(db)
                        
                        return (identity, token.value)
                    }

                    @Dependency(\.fireAndForget) var fireAndForget
                    await fireAndForget {
                        try await sendVerificationEmail(emailAddress, tokenValue)
                    }

                    logger.notice("User created", metadata: [
                        "component": "Backend.Create",
                        "operation": "request",
                        "identityId": "\(identity.id)"
                    ])
                } catch {
                    logger.error("User creation failed", metadata: [
                        "component": "Backend.Create",
                        "operation": "request",
                        "error": "\(error)"
                    ])
                    throw error
                }
            },
            verify: { email, token in
                do {
                    let emailAddress = try EmailAddress(email)
                    
                    @Dependency(\.defaultDatabase) var db
                    
                    // Single transaction with JOIN for verification
                    let identity = try await db.write { db in
                        // Find token and identity in single JOIN query
                        let data = try await Identity.Token.Record
                            .where { $0.value.eq(token) }
                            .where { $0.type.eq(Identity.Token.Record.TokenType.emailVerification) }
                            .where { $0.validUntil > Date() }
                            .join(Identity.Record.all) { token, identity in
                                token.identityId.eq(identity.id)
                            }
                            .select { token, identity in
                                EmailVerificationData.Columns(
                                    token: token,
                                    identity: identity
                                )
                            }
                            .fetchOne(db)
                        
                        guard let data else {
                            throw Abort(.notFound, reason: "Invalid or expired token")
                        }
                        
                        // Verify email matches
                        guard data.identity.email == emailAddress else {
                            throw Abort(.badRequest, reason: "Email mismatch")
                        }
                        
                        // Update identity verification status
                        try await Identity.Record
                            .where { $0.id.eq(data.identity.id) }
                            .update {
                                $0.emailVerificationStatus = .verified
                            }
                            .execute(db)
                        
                        // DELETE the token (cleaner than UPDATE)
                        try await Identity.Token.Record
                            .delete()
                            .where { $0.identityId.eq(data.identity.id) }
                            .where { $0.type.eq(Identity.Token.Record.TokenType.emailVerification) }
                            .execute(db)
                        
                        return data.identity
                    }

                    @Dependency(\.fireAndForget) var fireAndForget
                    let identityId = identity.id
                    let identityEmail = identity.email
                    await fireAndForget {
                        try await onIdentityCreationSuccess((identityId, identityEmail))
                    }
                } catch {
                    throw Abort(.internalServerError, reason: "Verification failed: \(error.localizedDescription)")
                }
            }
        )
    }
}
