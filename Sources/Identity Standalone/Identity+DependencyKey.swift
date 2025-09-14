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
import Language
import URLRouting


extension Identity: @retroactive DependencyKey {
    public static var liveValue: Self {
        @Dependency(Identity.Standalone.Configuration.self) var configuration
        

        return .init(
            authenticate: .init(
                client: .live(),
                router: Authentication.Route.Router(),
                token: .live()
            ),
            logout: Logout.init(client: .init()),
            reauthorize: .init(client: .init()),
            create: .init(
                client: .live(
                    sendVerificationEmail: configuration.email!.sendVerificationEmail,
                    // who provides this? should this be a hook in configuration?
                    onIdentityCreationSuccess: configuration.email!.onIdentityCreationSuccess
                )
            ),
            delete: .init(
                client: .live(
                    sendDeletionRequestNotification: configuration.email!.sendDeletionRequestNotification,
                    sendDeletionConfirmationNotification: configuration.email!.sendDeletionConfirmationNotification
                )
            ),
            email: .init(
                change: .init(
                    client: .live(
                        sendEmailChangeConfirmation: configuration.email!.sendEmailChangeConfirmation,
                        sendEmailChangeRequestNotification: configuration.email!.sendEmailChangeRequestNotification,
                        onEmailChangeSuccess: configuration.email!.onEmailChangeSuccess
                    )
                )
            ),
            password: .init(
                change: .init(client: .init()),
                reset: .init(client: .init())
            )
        )
    }
}
