//
//  Identity.Backend.Client.live.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import Dependencies
import IdentitiesTypes
import JWT
import EmailAddress

extension Identity.Backend.Client {
    /// Creates a live backend client with direct database access.
    ///
    /// This implementation provides the core business logic for identity operations,
    /// including database access, token generation, and email sending.
    public static func live(
        sendVerificationEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String) async throws -> Void,
        sendPasswordResetEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String) async throws -> Void,
        sendPasswordChangeNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
        sendEmailChangeConfirmation: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress, _ token: String) async throws -> Void,
        sendEmailChangeRequestNotification: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void,
        onEmailChangeSuccess: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void,
        sendDeletionRequestNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
        sendDeletionConfirmationNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
        onIdentityCreationSuccess: @escaping @Sendable (_ identity: (id: UUID, email: EmailAddress)) async throws -> Void = { _ in },
        mfaConfiguration: Identity.MFA.TOTP.Configuration? = nil
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.defaultDatabase) var database

        return .init(
            authenticate: .live(),
            logout: .init(
                current: {
                    @Dependency(\.request) var request
                    guard let request else { throw Abort.requestUnavailable }
                    
                    do {
                        var identity = try await Database.Identity.get(by: .auth)
                        identity.sessionVersion += 1
                        try await identity.save()
                    } catch {
                        // Identity not found - likely database was reset but cookies persist
                        // This is common in development when restarting the server
                        logger.info("Logout attempted for non-existent identity - clearing session")
                    }
                    
                    // Always logout from the session regardless of whether identity exists
                    request.auth.logout(Database.Identity.self)
                },
                all: {
                    do {
                        // Increment session version to invalidate all existing tokens
                        var identity = try await Database.Identity.get(by: .auth)
                        identity.sessionVersion += 1
                        try await identity.save()
                        logger.notice("Logout all sessions for identity: \(identity.id)")
                    } catch {
                        // Identity not found - likely database was reset but cookies persist
                        logger.info("Logout all attempted for non-existent identity - session already invalid")
                    }
                    // No need to clear current session as it's already invalid
                }
            ),
            reauthorize: { password in
                do {
                    let identity = try await Database.Identity.get(by: .auth)

                    guard try identity.verifyPassword(password)
                    else { throw Identity.Backend.AuthenticationError.invalidCredentials }

                    @Dependency(\.tokenClient) var tokenClient
                    
                    let token = try await tokenClient.generateReauthorization(
                        identity.id,
                        identity.sessionVersion,
                        "general",
                        []
                    )
                    
                    return try JWT.parse(from: token)
                } catch {
                    logger.error("Reauthorization failed: \(error)")
                    throw error
                }
            },
            create: .live(
                sendVerificationEmail: sendVerificationEmail,
                onIdentityCreationSuccess: onIdentityCreationSuccess
            ),
            delete: .live(
                sendDeletionRequestNotification: sendDeletionRequestNotification,
                sendDeletionConfirmationNotification: sendDeletionConfirmationNotification
            ),
            email: .live(
                sendEmailChangeConfirmation: sendEmailChangeConfirmation,
                sendEmailChangeRequestNotification: sendEmailChangeRequestNotification,
                onEmailChangeSuccess: onEmailChangeSuccess
            ),
            password: .live(
                sendPasswordResetEmail: sendPasswordResetEmail,
                sendPasswordChangeNotification: sendPasswordChangeNotification
            ),
            mfa: mfaConfiguration.map { config in
                Identity.Client.MFA(
                    totp: Identity.Client.MFA.TOTP.live(configuration: config),
                    backupCodes: Identity.Backend.Client.MFA.backupCodesLive(configuration: config),
                    status: Identity.Client.MFA.Status.live()
                )
            }
        )
    }
}

extension Identity.Backend.Client {
    public static func logging(
        router: AnyParserPrinter<URLRequestData, Identity.Route>,
        mfaConfiguration: Identity.MFA.TOTP.Configuration? = nil
    ) -> Self {
        return .live(
            sendVerificationEmail: { email, token in
                @Dependency(\.logger) var logger
                logger.info("Demo: Verification email triggered", metadata: [
                    "component": "Demo",
                    "operation": "sendVerificationEmail",
                    "email": "\(email)",
                    "verificationUrl": "\(router.url(for: .view(.create(.verify(.init(token: token, email: email.rawValue))))))"
                ])
            },
            sendPasswordResetEmail: { email, token in
                @Dependency(\.logger) var logger
                logger.info("Demo: Password reset email triggered", metadata: [
                    "component": "Demo",
                    "operation": "sendPasswordResetEmail",
                    "email": "\(email)"
                ])
            },
            sendPasswordChangeNotification: { email in
                @Dependency(\.logger) var logger
                logger.info("Demo: Password change notification triggered", metadata: [
                    "component": "Demo",
                    "operation": "sendPasswordChangeNotification",
                    "email": "\(email)"
                ])
            },
            sendEmailChangeConfirmation: { currentEmail, newEmail, token in
                @Dependency(\.logger) var logger
                let verificationURL = router.url(for: .api(.email(.change(.confirm(.init(token: token))))))
                
                logger.info("Demo: Email change confirmation triggered", metadata: [
                    "component": "Demo",
                    "operation": "sendEmailChangeConfirmation",
                    "currentEmail": "\(currentEmail)",
                    "newEmail": "\(newEmail)",
                    "verificationUrl": "\(verificationURL.absoluteString)",
                ])
            },
            sendEmailChangeRequestNotification: { currentEmail, newEmail in
                @Dependency(\.logger) var logger
                logger.info("Demo: Email change request notification triggered", metadata: [
                    "component": "Demo",
                    "operation": "sendEmailChangeRequestNotification",
                    "currentEmail": "\(currentEmail)",
                    "newEmail": "\(newEmail)"
                ])
            },
            onEmailChangeSuccess: { currentEmail, newEmail in
                @Dependency(\.logger) var logger
                logger.notice("Demo: Email changed successfully", metadata: [
                    "component": "Demo",
                    "operation": "onEmailChangeSuccess",
                    "currentEmail": "\(currentEmail)",
                    "newEmail": "\(newEmail)"
                ])
            },
            sendDeletionRequestNotification: { email in
                @Dependency(\.logger) var logger
                logger.info("Demo: Deletion request notification triggered", metadata: [
                    "component": "Demo",
                    "operation": "sendDeletionRequestNotification",
                    "email": "\(email)"
                ])
            },
            sendDeletionConfirmationNotification: { email in
                @Dependency(\.logger) var logger
                logger.info("Demo: Deletion confirmation triggered", metadata: [
                    "component": "Demo",
                    "operation": "sendDeletionConfirmationNotification",
                    "email": "\(email)"
                ])
            },
            onIdentityCreationSuccess: { identity in
                @Dependency(\.logger) var logger
                logger.notice("Demo: Identity created successfully", metadata: [
                    "component": "Demo",
                    "operation": "onIdentityCreationSuccess",
                    "identityId": "\(identity.id)",
                    "email": "\(identity.email)"
                ])
            },
            mfaConfiguration: mfaConfiguration
        )
    }
}
