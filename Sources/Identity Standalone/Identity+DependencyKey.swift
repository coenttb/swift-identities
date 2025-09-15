//
//  File.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 14/09/2025.
//

import Identity_Frontend
import Identity_Backend
import Identity_Shared
import IdentitiesTypes
import Dependencies
import ServerFoundation
import ServerFoundationVapor
import Language
import URLRouting
import Records
import JWT


// MARK: - Helper Functions





extension Identity: @retroactive DependencyKey {
    public static var liveValue: Self {
        @Dependency(Identity.Standalone.Configuration.self) var configuration

        let router = configuration.router
        let emailConfig = configuration.email  // Now required, defaults to .noop

        return .init(
            authenticate: .init(
                client: .live(),
                router: router.authentication,
                token: .live()
            ),
            logout: Logout.init(
                client: .init(
                    current: {
                        @Dependency(\.request) var request
                        guard let request else { throw Abort.requestUnavailable }

                        do {
                            let identity = try await Identity.Record.get(by: .auth)

                            @Dependency(\.defaultDatabase) var db
                            @Dependency(\.date) var date

                            try await db.write { db in
                                try await Identity.Record
                                    .where { $0.id.eq(identity.id) }
                                    .update { record in
                                        record.sessionVersion = record.sessionVersion + 1
                                        record.updatedAt = date()
                                    }
                                    .execute(db)
                            }
                        } catch {
                            // Identity not found - likely database was reset but cookies persist
                            @Dependency(\.logger) var logger
                            logger.info("Logout attempted for non-existent identity - clearing session")
                        }

                        request.auth.logout(Identity.Record.self)
                    },
                    all: {
                        do {
                            let identity = try await Identity.Record.get(by: .auth)

                            @Dependency(\.defaultDatabase) var db
                            @Dependency(\.date) var date
                            try await db.write { db in
                                try await Identity.Record
                                    .where { $0.id.eq(identity.id) }
                                    .update { record in
                                        record.sessionVersion = record.sessionVersion + 1
                                        record.updatedAt = date()
                                    }
                                    .execute(db)
                            }
                            @Dependency(\.logger) var logger
                            logger.notice("Logout all sessions for identity: \(identity.id)")
                        } catch {
                            @Dependency(\.logger) var logger
                            logger.info("Logout all attempted for non-existent identity - session already invalid")
                        }
                    }
                ),
                router: router.logout
            ),
            reauthorize: .init(
                client: .init(
                    reauthorize: { password in
                        do {
                            let identity = try await Identity.Record.get(by: .auth)

                            guard try await identity.verifyPassword(password)
                            else { throw Identity.Authentication.Error.invalidCredentials }

                            @Dependency(\.tokenClient) var tokenClient

                            let token = try await tokenClient.generateReauthorization(
                                identity.id,
                                identity.sessionVersion,
                                "general",
                                []
                            )

                            return try JWT.parse(from: token)
                        } catch {
                            @Dependency(\.logger) var logger
                            logger.error("Reauthorization failed: \(error)")
                            throw error
                        }
                    }
                ),
                router: router.reauthorization
            ),
            create: .init(
                client: .live(
                    sendVerificationEmail: emailConfig.sendVerificationEmail,
                    onIdentityCreationSuccess: emailConfig.onIdentityCreationSuccess
                ),
                router: router.creation
            ),
            delete: .init(
                client: .live(
                    sendDeletionRequestNotification: emailConfig.sendDeletionRequestNotification,
                    sendDeletionConfirmationNotification: emailConfig.sendDeletionConfirmationNotification
                ),
                router: router.deletion
            ),
            email: .init(
                change: .init(
                    client: .live(
                        sendEmailChangeConfirmation: emailConfig.sendEmailChangeConfirmation,
                        sendEmailChangeRequestNotification: emailConfig.sendEmailChangeRequestNotification,
                        onEmailChangeSuccess: emailConfig.onEmailChangeSuccess
                    ),
                    router: router.email.api.change
                ),
                router: router.email
            ),
            password: .init(
                change: .init(
                    client: .live(
                        sendPasswordChangeNotification: emailConfig.sendPasswordChangeNotification
                    ),
                    router: router.password.api.change
                ),
                reset: .init(
                    client: .live(
                        sendPasswordResetEmail: emailConfig.sendPasswordResetEmail,
                        sendPasswordChangeNotification: emailConfig.sendPasswordChangeNotification
                    ),
                    router: router.password.api.reset
                ),
                router: router.password
            ),
            mfa: configuration.mfa.map { mfaConfig in
                Identity.MFA(from: mfaConfig)
            },
            oauth: configuration.oauth.map { oauthConfig in
                Identity.OAuth(from: oauthConfig)
            },
            router: router
        )
    }
}
