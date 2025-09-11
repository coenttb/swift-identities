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

extension Identity {
    /// Creates a live backend Identity with direct database access.
    ///
    /// This implementation provides the core business logic for identity operations,
    /// including database access, token generation, and email sending.
    public static func backend(
        sendVerificationEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String) async throws -> Void,
        sendPasswordResetEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String) async throws -> Void,
        sendPasswordChangeNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
        sendEmailChangeConfirmation: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress, _ token: String) async throws -> Void,
        sendEmailChangeRequestNotification: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void,
        onEmailChangeSuccess: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void,
        sendDeletionRequestNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
        sendDeletionConfirmationNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
        onIdentityCreationSuccess: @escaping @Sendable (_ identity: (id: Identity.ID, email: EmailAddress)) async throws -> Void = { _ in },
        mfaConfiguration: Identity.MFA.TOTP.Configuration? = nil,
        oauthProviderRegistry: OAuthProviderRegistry? = nil
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.defaultDatabase) var database

        return Identity(
            authenticate: Identity.Authentication(
                client: .live(),
                router: Identity.Authentication.Route.Router(),
                token: .live()
            ),
            logout: Identity.Logout(
                client: .init(
                    current: {
                    @Dependency(\.request) var request
                    guard let request else { throw Abort.requestUnavailable }
                    
                    do {
                        var identity = try await Identity.Record.get(by: .auth)
                        identity.sessionVersion += 1
                        try await identity.save()
                    } catch {
                        // Identity not found - likely database was reset but cookies persist
                        // This is common in development when restarting the server
                        logger.info("Logout attempted for non-existent identity - clearing session")
                    }
                    
                    // Always logout from the session regardless of whether identity exists
                    request.auth.logout(Identity.Record.self)
                },
                all: {
                    do {
                        // Increment session version to invalidate all existing tokens
                        var identity = try await Identity.Record.get(by: .auth)
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
                router: Identity.Logout.Route.Router()
            ),
            reauthorize: Identity.Reauthorization(
                client: .init(
                    reauthorize: { password in
                        do {
                    let identity = try await Identity.Record.get(by: .auth)

                    guard try await identity.verifyPassword(password)
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
                    }
                ),
                router: Identity.Reauthorization.Request.Router()
            ),
            create: Identity.Creation(
                client: .live(
                    sendVerificationEmail: sendVerificationEmail,
                    onIdentityCreationSuccess: onIdentityCreationSuccess
                ),
                router: Identity.Creation.Route.Router()
            ),
            delete: Identity.Deletion(
                client: .live(
                    sendDeletionRequestNotification: sendDeletionRequestNotification,
                    sendDeletionConfirmationNotification: sendDeletionConfirmationNotification
                ),
                router: Identity.Deletion.Route.Router()
            ),
            email: Identity.Email(
                change: Identity.Email.Change(
                    client: .live(
                        sendEmailChangeConfirmation: sendEmailChangeConfirmation,
                        sendEmailChangeRequestNotification: sendEmailChangeRequestNotification,
                        onEmailChangeSuccess: onEmailChangeSuccess
                    ),
                    router: Identity.Email.Change.API.Router()
                ),
                router: Identity.Email.Route.Router()
            ),
            password: Identity.Password(
                change: Identity.Password.Change(
                    client: Identity.Password.Client.live(
                        sendPasswordResetEmail: sendPasswordResetEmail,
                        sendPasswordChangeNotification: sendPasswordChangeNotification
                    ).change,
                    router: Identity.Password.Change.API.Router()
                ),
                reset: Identity.Password.Reset(
                    client: Identity.Password.Client.live(
                        sendPasswordResetEmail: sendPasswordResetEmail,
                        sendPasswordChangeNotification: sendPasswordChangeNotification
                    ).reset,
                    router: Identity.Password.Reset.API.Router()
                ),
                router: Identity.Password.Route.Router()
            ),
            mfa: mfaConfiguration.map { config in
                Identity.MFA(
                    totp: Identity.MFA.TOTP(
                        client: Identity.MFA.TOTP.Client.live(configuration: config),
                        router: Identity.MFA.TOTP.API.Router()
                    ),
                    sms: Identity.MFA.SMS(
                        client: .init(),  // Not implemented yet
                        router: Identity.MFA.SMS.API.Router()
                    ),
                    email: Identity.MFA.Email(
                        client: .init(),  // Not implemented yet
                        router: Identity.MFA.Email.API.Router()
                    ),
                    webauthn: Identity.MFA.WebAuthn(
                        client: .init(),  // Not implemented yet
                        router: Identity.MFA.WebAuthn.API.Router()
                    ),
                    backupCodes: Identity.MFA.BackupCodes(
                        client: Identity.MFA.BackupCodes.Client.live(configuration: config),
                        router: Identity.MFA.BackupCodes.API.Router()
                    ),
                    status: Identity.MFA.Status(
                        client: Identity.MFA.Status.Client.live(),
                        router: Identity.MFA.Status.API.Router()
                    ),
                    router: Identity.MFA.Route.Router()
                )
            },
            oauth: oauthProviderRegistry.map { registry in
                @Dependency(Identity.Token.Client.self) var encryption
                
                let stateManager = OAuthStateManager()
                return Identity.OAuth(
                    client: Identity.OAuth.Client.live(
                        registry: registry,
                        stateManager: stateManager
                    ),
                    router: Identity.OAuth.Route.Router()
                )
            }
        )
    }
}

extension Identity.Backend {
    public static func logging(
        router: AnyParserPrinter<URLRequestData, Identity.Route>,
        mfaConfiguration: Identity.MFA.TOTP.Configuration? = nil,
        oauthProviderRegistry: OAuthProviderRegistry? = nil
    ) -> Identity {
        return Identity.backend(
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
            mfaConfiguration: mfaConfiguration,
            oauthProviderRegistry: oauthProviderRegistry
        )
    }
}
