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

                    // Check if email already exists
                    @Dependency(\.defaultDatabase) var db
                    let existingIdentity = try await db.read { db in
                        try await Identity.Record
                            .where { $0.emailString.eq(emailAddress.rawValue) }
                            .fetchOne(db)
                    }
                    guard existingIdentity == nil else {
                        throw Identity.Authentication.ValidationError.invalidInput("Email already in use")
                    }

                    // Create the identity
                    @Dependency(\.uuid) var uuid
                    @Dependency(\.date) var date
                    @Dependency(\.envVars) var envVars
                    @Dependency(\.application) var application
                    
                    let passwordHash: String = try await application.threadPool.runIfActive {
                        try Bcrypt.hash(password, cost: envVars.bcryptCost)
                    }
                    
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
                    
                    // Insert the new identity
                    try await db.write { db in
                        try await Identity.Record
                            .insert { identity }
                            .execute(db)
                    }

                    // Single transaction for token creation
                    let tokenValue = try await db.write { db in
                        // Invalidate any existing verification tokens
                        try await Identity.Token.Record
                            .delete()
                            .where { $0.identityId.eq(identity.id) }
                            .where { $0.type.eq(Identity.Token.Record.TokenType.emailVerification) }
                            .execute(db)
                        
                        @Dependency(\.uuid) var uuid
                        @Dependency(\.date) var date
                        
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
                        
                        return token.value
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
                    
                    // Find valid verification token
                    guard let identityToken = try await db.read ({ db in
                        try await Identity.Token.Record
                            .where { tokenRecord in
                                tokenRecord.value.eq(token) &&
                                tokenRecord.type.eq(Identity.Token.Record.TokenType.emailVerification) &&
                                #sql("\(tokenRecord.validUntil) > CURRENT_TIMESTAMP")
                            }
                            .fetchOne(db)
                    }) else {
                        throw Abort(.notFound, reason: "Invalid or expired token")
                    }

                    // Get the associated identity
                    guard let identity = try await db.read({ db in
                        try await Identity.Record
                            .where { $0.id.eq(identityToken.identityId) }
                            .fetchOne(db)
                    }) else {
                        throw Abort(.notFound, reason: "Identity not found")
                    }

                    // Verify email matches
                    guard identity.email == emailAddress else {
                        throw Abort(.badRequest, reason: "Email mismatch")
                    }

                    // Update identity verification status
                    
                    try await db.write { db in
                        try await Identity.Record
                            .where { $0.id.eq(identityToken.identityId) }
                            .update {
                                $0.emailVerificationStatus = .verified
                            }
                            .execute(db)
                    }

                    // Invalidate the token
                    try await db.write { db in
                        try await Identity.Token.Record
                            .delete()
                            .where { $0.identityId.eq(identity.id) }
                            .where { $0.type.eq(Identity.Token.Record.TokenType.emailVerification) }
                            .execute(db)
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
