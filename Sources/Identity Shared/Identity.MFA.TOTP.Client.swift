import Dependencies
import DependenciesMacros
import Foundation
import IdentitiesTypes
import TOTP
import RFC_6238

// MARK: - Configuration
// This stays in Identity Shared because it has implementation dependencies (RFC_6238)

extension Identity.MFA.TOTP {
    public struct Configuration: Sendable {
        public let issuer: String
        public let algorithm: Algorithm
        public let digits: Int
        public let timeStep: TimeInterval
        public let verificationWindow: Int
        public let backupCodeLength: Int
        public let backupCodeCount: Int
        
        public typealias Algorithm = RFC_6238.TOTP.Algorithm
        
        public init(
            issuer: String,
            algorithm: Algorithm = .sha1,
            digits: Int = 6,
            timeStep: TimeInterval = 30,
            verificationWindow: Int = 1,
            backupCodeLength: Int = 8,
            backupCodeCount: Int = 10
        ) throws {
            guard !issuer.isEmpty else {
                throw ConfigurationError.invalidIssuer("Issuer cannot be empty")
            }
            guard digits >= 6 && digits <= 8 else {
                throw ConfigurationError.invalidDigits("Digits must be between 6 and 8")
            }
            guard timeStep > 0 && timeStep <= 300 else {
                throw ConfigurationError.invalidTimeStep("Time step must be between 1 and 300 seconds")
            }
            guard verificationWindow >= 0 && verificationWindow <= 10 else {
                throw ConfigurationError.invalidWindow("Verification window must be between 0 and 10")
            }
            guard backupCodeLength >= 6 && backupCodeLength <= 16 else {
                throw ConfigurationError.invalidBackupCodeLength("Backup code length must be between 6 and 16")
            }
            guard backupCodeCount >= 0 && backupCodeCount <= 20 else {
                throw ConfigurationError.invalidBackupCodeCount("Backup code count must be between 0 and 20")
            }
            
            self.issuer = issuer
            self.algorithm = algorithm
            self.digits = digits
            self.timeStep = timeStep
            self.verificationWindow = verificationWindow
            self.backupCodeLength = backupCodeLength
            self.backupCodeCount = backupCodeCount
        }
        
        public static var `default`: Self {
            try! .init(issuer: "Identity Provider")
        }
        
        public enum ConfigurationError: Error, Equatable {
            case invalidIssuer(String)
            case invalidDigits(String)
            case invalidTimeStep(String)
            case invalidWindow(String)
            case invalidBackupCodeLength(String)
            case invalidBackupCodeCount(String)
        }
    }
}

// MARK: - Test Implementation
// The Client type is now defined in swift-identities-types

extension Identity.MFA.TOTP.Client: TestDependencyKey {
    public static var testValue: Self {
        Self()
    }
}

// MARK: - Dependency Values

extension DependencyValues {
    public var totpClient: Identity.MFA.TOTP.Client {
        get { self[Identity.MFA.TOTP.Client.self] }
        set { self[Identity.MFA.TOTP.Client.self] = newValue }
    }
}