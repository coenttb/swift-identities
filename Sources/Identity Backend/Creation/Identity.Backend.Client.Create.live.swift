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
                    guard try await Identity.Record.findByEmail(emailAddress) == nil else {
                        throw Identity.Backend.ValidationError.invalidInput("Email already in use")
                    }

                    // Create the identity
                    let identity = try await Identity.Record(
                        email: emailAddress,
                        password: password,
                        emailVerificationStatus: .unverified
                    )

                    // Invalidate any existing verification tokens
                    try await Identity.Authentication.Token.Record.invalidateAllForIdentity(identity.id, type: .emailVerification)

//                     guard try await identity.canGenerateToken() else {
//                         throw Abort(.tooManyRequests, reason: "Token generation limit exceeded")
//                     }

                    // Create verification token
                    let verificationToken = try await Identity.Authentication.Token.Record(
                        identityId: identity.id,
                        type: .emailVerification,
                        validityHours: 24 // 24 hours
                    )
                    
                    let tokenValue = verificationToken.value

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
                    
                    // Find valid verification token
                    guard let identityToken = try await Identity.Authentication.Token.Record.findValid(value: token, type: .emailVerification) else {
                        throw Abort(.notFound, reason: "Invalid or expired token")
                    }

                    // Get the associated identity
                    guard var identity = try await Identity.Record.findById(identityToken.identityId) else {
                        throw Abort(.notFound, reason: "Identity not found")
                    }

                    // Verify email matches
                    guard identity.email == emailAddress else {
                        throw Abort(.badRequest, reason: "Email mismatch")
                    }

                    // Update identity verification status
                    try await identity.updateEmailVerificationStatus(.verified)

                    // Invalidate the token
                    try await Identity.Authentication.Token.Record.invalidateAllForIdentity(identity.id, type: .emailVerification)

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
