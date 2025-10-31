//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 12/09/2024.
//

import Dependencies
import EmailAddress
import IdentitiesTypes
import Records
import ServerFoundation
import Vapor

extension Identity.Password.Client {
  package static func live(
    sendPasswordResetEmail: @escaping @Sendable (_ email: EmailAddress, _ token: String)
      async throws -> Void,
    sendPasswordChangeNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void
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
