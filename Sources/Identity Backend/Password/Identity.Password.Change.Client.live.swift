//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 12/09/2024.
//

import ServerFoundation
import IdentitiesTypes
import Vapor
import Dependencies
import EmailAddress
import Records


extension Identity.Password.Change.Client {
    package static func live(
        sendPasswordChangeNotification: @escaping @Sendable (_ email: EmailAddress) async throws -> Void
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.passwordValidation.validate) var validatePassword
        
        return .init(
            request: { currentPassword, newPassword in
                let identity = try await Identity.Record.get(by: .auth)

                guard try await identity.verifyPassword(currentPassword) else {
                    throw Identity.Authentication.Error.invalidCredentials
                }

                _ = try validatePassword(newPassword)

                @Dependency(\.defaultDatabase) var db
                @Dependency(\.date) var date
                @Dependency(\.envVars) var envVars
                @Dependency(\.application) var application
                
                // Hash the new password
                let passwordHash: String = try await application.threadPool.runIfActive {
                    try Bcrypt.hash(newPassword, cost: envVars.bcryptCost)
                }
                
                // Update password and increment session version atomically
                try await db.write { db in
                    try await Identity.Record
                        .where { $0.id.eq(identity.id) }
                        .update { record in
                            record.passwordHash = passwordHash
                            record.sessionVersion = record.sessionVersion + 1
                            record.updatedAt = date()
                        }
                        .execute(db)
                }

                let emailAddress = identity.email
                
                @Dependency(\.fireAndForget) var fireAndForget
                await fireAndForget {
                    try await sendPasswordChangeNotification(emailAddress)
                }

                logger.notice("Password changed", metadata: [
                    "component": "Backend.Password",
                    "operation": "change",
                    "identityId": "\(identity.id)"
                ])
            }
        )
    }
}
