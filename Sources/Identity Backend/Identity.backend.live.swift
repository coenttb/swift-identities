////
////  Identity.Backend.Client.live.swift
////  coenttb-identities
////
////  Created by Coen ten Thije Boonkkamp on 29/01/2025.
////
//
//@preconcurrency import ServerFoundationVapor
//import Dependencies
//import IdentitiesTypes
//import JWT
//import EmailAddress
//import Records
//
//extension Identity.Backend {
//    /// Creates a live backend Identity using configuration from dependency injection.
//    ///
//    /// This implementation provides the core business logic for identity operations,
//    /// including database access, token generation, and email sending.
//    public static func live() -> Identity {
//        @Dependency(Identity.Backend.Configuration.self) var configuration
//
//        return live(
//            router: configuration.router,
//            sendVerificationEmail: configuration.email.sendVerificationEmail,
//            sendPasswordResetEmail: configuration.email.sendPasswordResetEmail,
//            sendPasswordChangeNotification: configuration.email.sendPasswordChangeNotification,
//            sendEmailChangeConfirmation: configuration.email.sendEmailChangeConfirmation,
//            sendEmailChangeRequestNotification: configuration.email.sendEmailChangeRequestNotification,
//            onEmailChangeSuccess: configuration.email.onEmailChangeSuccess,
//            sendDeletionRequestNotification: configuration.email.sendDeletionRequestNotification,
//            sendDeletionConfirmationNotification: configuration.email.sendDeletionConfirmationNotification,
//            onIdentityCreationSuccess: configuration.email.onIdentityCreationSuccess,
//            mfaConfiguration: configuration.mfa,
//            oauthConfiguration: configuration.oauth
//        )
//    }
//
//    /// Creates a live backend Identity with direct parameter specification.
//    /// This is kept for backward compatibility and testing.
//    ///
//    /// Prefer using `live()` which uses configuration from dependency injection.
//    public static func live(
//        router: any URLRouting.Router<Identity.Authentication.Route> = Identity.Authentication.Route.Router(),
//        require: @escaping @Sendable () async throws -> Identity.Context,
//        sendVerificationEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String) async throws -> Void,
//        sendPasswordResetEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String) async throws -> Void,
//        sendPasswordChangeNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
//        sendEmailChangeConfirmation: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress, _ token: String) async throws -> Void,
//        sendEmailChangeRequestNotification: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void,
//        onEmailChangeSuccess: @escaping @Sendable (_ currentEmail: EmailAddress, _ newEmail: EmailAddress) async throws -> Void,
//        sendDeletionRequestNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
//        sendDeletionConfirmationNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void,
//        onIdentityCreationSuccess: @escaping @Sendable (_ identity: (id: Identity.ID, email: EmailAddress)) async throws -> Void = { _ in },
//        mfaConfiguration: Identity.MFA?,
//        oauthConfiguration: Identity.OAuth? = nil
//    ) -> Identity {
//        @Dependency(\.logger) var logger
//        @Dependency(\.defaultDatabase) var database
//
//        return Identity(
//            authenticate: Identity.Authentication(
//                client: .live(),
//                router: router,
//                token: .live()
//            ),
//            logout: Identity.Logout(
//                client: .init(
//                    current: {
//                    @Dependency(\.request) var request
//                    guard let request else { throw Abort.requestUnavailable }
//                    
//                    do {
//                        let identity = try await Identity.Record.get(by: .auth)
//                        
//                        // Increment session version to invalidate all tokens
//                        @Dependency(\.defaultDatabase) var db
//                        @Dependency(\.date) var date
//                        
//                        try await db.write { db in
//                            try await Identity.Record
//                                .where { $0.id.eq(identity.id) }
//                                .update { record in
//                                    record.sessionVersion = record.sessionVersion + 1
//                                    record.updatedAt = date()
//                                }
//                                .execute(db)
//                        }
//                    } catch {
//                        // Identity not found - likely database was reset but cookies persist
//                        // This is common in development when restarting the server
//                        logger.info("Logout attempted for non-existent identity - clearing session")
//                    }
//                    
//                    // Always logout from the session regardless of whether identity exists
//                    request.auth.logout(Identity.Record.self)
//                },
//                all: {
//                    do {
//                        // Increment session version to invalidate all existing tokens
//                        let identity = try await Identity.Record.get(by: .auth)
//                        
//                        @Dependency(\.defaultDatabase) var db
//                        @Dependency(\.date) var date
//                        try await db.write { db in
//                            try await Identity.Record
//                                .where { $0.id.eq(identity.id) }
//                                .update { record in
//                                    record.sessionVersion = record.sessionVersion + 1
//                                    record.updatedAt = date()
//                                }
//                                .execute(db)
//                        }
//                        logger.notice("Logout all sessions for identity: \(identity.id)")
//                    } catch {
//                        // Identity not found - likely database was reset but cookies persist
//                        logger.info("Logout all attempted for non-existent identity - session already invalid")
//                    }
//                    // No need to clear current session as it's already invalid
//                }
//                ),
//                router: Identity.Logout.Route.Router()
//            ),
//            reauthorize: Identity.Reauthorization(
//                client: .init(
//                    reauthorize: { password in
//                        do {
//                    let identity = try await Identity.Record.get(by: .auth)
//
//                    guard try await identity.verifyPassword(password)
//                    else { throw Identity.Authentication.Error.invalidCredentials }
//
//                    @Dependency(\.tokenClient) var tokenClient
//                    
//                    let token = try await tokenClient.generateReauthorization(
//                        identity.id,
//                        identity.sessionVersion,
//                        "general",
//                        []
//                    )
//                    
//                    return try JWT.parse(from: token)
//                        } catch {
//                            logger.error("Reauthorization failed: \(error)")
//                            throw error
//                        }
//                    }
//                ),
//                router: Identity.Reauthorization.Route.Router()
//            ),
//            require: require,
//            create: Identity.Creation(
//                client: .live(
//                    sendVerificationEmail: sendVerificationEmail,
//                    onIdentityCreationSuccess: onIdentityCreationSuccess
//                ),
//                router: Identity.Creation.Route.Router()
//            ),
//            delete: Identity.Deletion(
//                client: .live(
//                    sendDeletionRequestNotification: sendDeletionRequestNotification,
//                    sendDeletionConfirmationNotification: sendDeletionConfirmationNotification
//                ),
//                router: Identity.Deletion.Route.Router()
//            ),
//            email: Identity.Email(
//                change: Identity.Email.Change(
//                    client: .live(
//                        sendEmailChangeConfirmation: sendEmailChangeConfirmation,
//                        sendEmailChangeRequestNotification: sendEmailChangeRequestNotification,
//                        onEmailChangeSuccess: onEmailChangeSuccess
//                    ),
//                    router: Identity.Email.Change.API.Router()
//                ),
//                router: Identity.Email.Route.Router()
//            ),
//            password: Identity.Password(
//                change: Identity.Password.Change(
//                    client: Identity.Password.Client.live(
//                        sendPasswordResetEmail: sendPasswordResetEmail,
//                        sendPasswordChangeNotification: sendPasswordChangeNotification
//                    ).change,
//                    router: Identity.Password.Change.API.Router()
//                ),
//                reset: Identity.Password.Reset(
//                    client: Identity.Password.Client.live(
//                        sendPasswordResetEmail: sendPasswordResetEmail,
//                        sendPasswordChangeNotification: sendPasswordChangeNotification
//                    ).reset,
//                    router: Identity.Password.Reset.API.Router()
//                ),
//                router: Identity.Password.Route.Router()
//            ),
//            mfa: mfaConfiguration,
//            oauth: oauthConfiguration
//        )
//    }
//}
//
//extension Identity.Backend {
//    public static func logging(
//        router: any ParserPrinter<URLRequestData, Identity.Route>,
//        mfaConfiguration: Identity.MFA? = nil,
//        oauthConfiguration: Identity.OAuth? = nil
//    ) -> Identity {
//        return Identity.Backend.live(
//            sendVerificationEmail: { email, token in
//                @Dependency(\.logger) var logger
//                logger.info("Demo: Verification email triggered", metadata: [
//                    "component": "Demo",
//                    "operation": "sendVerificationEmail",
//                    "email": "\(email)",
//                    "verificationUrl": "\(router.url(for: .view(.create(.verify(.init(token: token, email: email.rawValue))))))"
//                ])
//            },
//            sendPasswordResetEmail: { email, token in
//                @Dependency(\.logger) var logger
//                logger.info("Demo: Password reset email triggered", metadata: [
//                    "component": "Demo",
//                    "operation": "sendPasswordResetEmail",
//                    "email": "\(email)"
//                ])
//            },
//            sendPasswordChangeNotification: { email in
//                @Dependency(\.logger) var logger
//                logger.info("Demo: Password change notification triggered", metadata: [
//                    "component": "Demo",
//                    "operation": "sendPasswordChangeNotification",
//                    "email": "\(email)"
//                ])
//            },
//            sendEmailChangeConfirmation: { currentEmail, newEmail, token in
//                @Dependency(\.logger) var logger
//                let verificationURL = router.url(for: .api(.email(.change(.confirm(.init(token: token))))))
//                
//                logger.info("Demo: Email change confirmation triggered", metadata: [
//                    "component": "Demo",
//                    "operation": "sendEmailChangeConfirmation",
//                    "currentEmail": "\(currentEmail)",
//                    "newEmail": "\(newEmail)",
//                    "verificationUrl": "\(verificationURL.absoluteString)",
//                ])
//            },
//            sendEmailChangeRequestNotification: { currentEmail, newEmail in
//                @Dependency(\.logger) var logger
//                logger.info("Demo: Email change request notification triggered", metadata: [
//                    "component": "Demo",
//                    "operation": "sendEmailChangeRequestNotification",
//                    "currentEmail": "\(currentEmail)",
//                    "newEmail": "\(newEmail)"
//                ])
//            },
//            onEmailChangeSuccess: { currentEmail, newEmail in
//                @Dependency(\.logger) var logger
//                logger.notice("Demo: Email changed successfully", metadata: [
//                    "component": "Demo",
//                    "operation": "onEmailChangeSuccess",
//                    "currentEmail": "\(currentEmail)",
//                    "newEmail": "\(newEmail)"
//                ])
//            },
//            sendDeletionRequestNotification: { email in
//                @Dependency(\.logger) var logger
//                logger.info("Demo: Deletion request notification triggered", metadata: [
//                    "component": "Demo",
//                    "operation": "sendDeletionRequestNotification",
//                    "email": "\(email)"
//                ])
//            },
//            sendDeletionConfirmationNotification: { email in
//                @Dependency(\.logger) var logger
//                logger.info("Demo: Deletion confirmation triggered", metadata: [
//                    "component": "Demo",
//                    "operation": "sendDeletionConfirmationNotification",
//                    "email": "\(email)"
//                ])
//            },
//            onIdentityCreationSuccess: { identity in
//                @Dependency(\.logger) var logger
//                logger.notice("Demo: Identity created successfully", metadata: [
//                    "component": "Demo",
//                    "operation": "onIdentityCreationSuccess",
//                    "identityId": "\(identity.id)",
//                    "email": "\(identity.email)"
//                ])
//            },
//            mfaConfiguration: mfaConfiguration,
//            oauthConfiguration: oauthConfiguration
//        )
//    }
//}
