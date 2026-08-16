//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 12/09/2024.
//

import Dependencies
import EmailAddress
import IdentitiesTypes
import Logger_Dependencies
import PasswordValidation
import Records
import Server

extension Identity.Password.Client {
    public static func live(
        sendPasswordResetEmail:
            @escaping @Sendable (_ email: EmailAddress, _ token: String)
            async throws -> Void,
        // swiftlint:disable:previous typed_throws_required
        sendPasswordChangeNotification:
            @escaping @Sendable (_ email: EmailAddress) async throws -> Void
            // swiftlint:disable:previous typed_throws_required
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.passwordValidation.validate) var validatePassword

        return .init(
            reset: .live(
                sendPasswordResetEmail: sendPasswordResetEmail,
                sendPasswordChangeNotification: sendPasswordChangeNotification
            ),
            change: .live(
                sendPasswordChangeNotification: sendPasswordChangeNotification
            )
        )
    }
}
