//
//  Identity.MFA.Email.Configuration.swift
//  swift-identities
//
//  Email configuration for multi-factor authentication
//

import Foundation
import IdentitiesTypes
import TypesFoundation

extension Identity.MFA.Email {
    /// Configuration for email-based multi-factor authentication
    /// Note: This is separate from account-related emails (password reset, etc.)
    public struct Configuration: Sendable {
        /// Callback to send email verification codes for MFA
        public var sendCode: @Sendable (EmailAddress, String) async throws -> Void

        /// The length of the generated verification code
        public var codeLength: Int

        /// How long the code remains valid (in seconds)
        public var expirationSeconds: Int

        /// Optional: Email subject line
        public var subject: String?

        /// Optional: Custom message template
        /// Use {code} as placeholder for the verification code
        public var messageTemplate: String?

        public init(
            sendCode: @escaping @Sendable (EmailAddress, String) async throws -> Void,
            codeLength: Int = 6,
            expirationSeconds: Int = 300,
            subject: String? = "Your verification code",
            messageTemplate: String? = nil
        ) {
            self.sendCode = sendCode
            self.codeLength = codeLength
            self.expirationSeconds = expirationSeconds
            self.subject = subject
            self.messageTemplate = messageTemplate
        }

        /// No-op configuration for testing
        public static var noop: Self {
            Self(
                sendCode: { _, _ in },
                codeLength: 6,
                expirationSeconds: 300
            )
        }

        /// Test configuration with logging
        public static var test: Self {
            Self(
                sendCode: { email, code in
                    print("[TEST] Email MFA code \(code) would be sent to \(email)")
                },
                codeLength: 6,
                expirationSeconds: 60,  // Shorter expiration for tests
                subject: "[TEST] Verification Code"
            )
        }
    }
}