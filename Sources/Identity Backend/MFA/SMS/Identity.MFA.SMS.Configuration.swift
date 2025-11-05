//
//  Identity.MFA.SMS.Configuration.swift
//  swift-identities
//
//  SMS configuration for multi-factor authentication
//

import Foundation
import IdentitiesTypes
import TypesFoundation

extension Identity.MFA.SMS {
    public typealias PhoneNumber = Tagged<Identity.MFA.SMS, String>
}

extension Identity.MFA.SMS {
    /// Configuration for SMS-based multi-factor authentication
    public struct Configuration: Sendable {
        /// Callback to send SMS verification codes
        /// First parameter is the phone number as a String, second is the verification code
        public var sendCode: @Sendable (String, String) async throws -> Void

        /// The length of the generated verification code
        public var codeLength: Int

        /// How long the code remains valid (in seconds)
        public var expirationSeconds: Int

        /// Optional: Custom message template
        /// Use {code} as placeholder for the verification code
        public var messageTemplate: String?

        public init(
            sendCode: @escaping @Sendable (String, String) async throws -> Void,
            codeLength: Int = 6,
            expirationSeconds: Int = 300,
            messageTemplate: String? = nil
        ) {
            self.sendCode = sendCode
            self.codeLength = codeLength
            self.expirationSeconds = expirationSeconds
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
                sendCode: { phone, code in
                    print("[TEST] SMS code \(code) would be sent to \(phone)")
                },
                codeLength: 6,
                expirationSeconds: 60  // Shorter expiration for tests
            )
        }
    }
}
