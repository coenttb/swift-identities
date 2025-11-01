//
//  Identity.Backend.Dependencies.swift
//  swift-identities
//
//  Common dependencies for Identity Backend operations
//

import Dependencies
import Foundation
import Logging
import Records
import ServerFoundationVapor

///// Protocol providing common dependencies for Identity Backend operations
//package protocol IdentityBackendDependencies {
//    var database: any Database.Writer { get }
//    var logger: Logger { get }
//    var date: DateGenerator { get }
//}
//
///// Default implementation using Dependencies library
//package struct DefaultIdentityBackendDependencies: IdentityBackendDependencies {
//    @Dependency(\.defaultDatabase) package var database
//    @Dependency(\.logger) package var logger
//    @Dependency(\.date) package var date
//
//    package init() {}
//}
//
///// Extension for convenient access to common dependencies
//extension Identity.Backend {
//    /// Shared dependencies instance for reducing duplication
//    package static var dependencies: IdentityBackendDependencies {
//        DefaultIdentityBackendDependencies()
//    }
//}

/// Constants for magic numbers used throughout Identity Backend
///
/// **DEPRECATED**: These constants are now configurable via `Identity.Backend.Configuration.Timeouts`.
/// Use `@Dependency(\.identityBackend.timeouts)` to access configurable timeouts instead.
extension Identity.Backend {
  package enum Constants {
    /// Default MFA attempts allowed
    /// - **DEPRECATED**: Use `Configuration.Timeouts.mfaMaxAttempts`
    @available(*, deprecated, message: "Use Configuration.Timeouts.mfaMaxAttempts")
    package static let mfaMaxAttempts = 3

    /// MFA session timeout in seconds
    /// - **DEPRECATED**: Use `Configuration.Timeouts.mfaSessionTimeout`
    @available(*, deprecated, message: "Use Configuration.Timeouts.mfaSessionTimeout")
    package static let mfaSessionTimeout: TimeInterval = 300  // 5 minutes

    /// Email verification token validity in hours
    /// - **DEPRECATED**: Use `Configuration.Timeouts.emailVerificationTokenValidity`
    @available(*, deprecated, message: "Use Configuration.Timeouts.emailVerificationTokenValidity")
    package static let emailVerificationTokenHours = 24

    /// Password reset token validity in hours
    /// - **DEPRECATED**: Use `Configuration.Timeouts.passwordResetTokenValidity`
    @available(*, deprecated, message: "Use Configuration.Timeouts.passwordResetTokenValidity")
    package static let passwordResetTokenHours = 1

    /// Default session token validity in hours
    /// - **DEPRECATED**: Use `Configuration.Timeouts.accessTokenValidity`
    @available(*, deprecated, message: "Use Configuration.Timeouts.accessTokenValidity")
    package static let sessionTokenHours = 24

    /// Refresh token validity in days
    /// - **DEPRECATED**: Use `Configuration.Timeouts.refreshTokenValidity`
    @available(*, deprecated, message: "Use Configuration.Timeouts.refreshTokenValidity")
    package static let refreshTokenDays = 30
  }
}
