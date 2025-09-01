import Dependencies
import DependenciesMacros
import Foundation
import IdentitiesTypes
import TOTP
import RFC_6238

extension Identity.MFA.TOTP {
    /// Client for managing TOTP operations
    @DependencyClient
    public struct Client: @unchecked Sendable {
        
        // MARK: - Setup Operations
        
        /// Generate a new TOTP secret for initial setup
        @DependencyEndpoint
        public var generateSecret: () async throws -> SetupData
        
        /// Confirm TOTP setup by verifying the initial code
        @DependencyEndpoint
        public var confirmSetup: (
            _ identityId: UUID,
            _ secret: String,
            _ code: String
        ) async throws -> Void
        
        // MARK: - Verification Operations
        
        /// Verify a TOTP code during authentication
        @DependencyEndpoint
        public var verifyCode: (
            _ identityId: UUID,
            _ code: String
        ) async throws -> Bool
        
        /// Verify a TOTP code with custom window
        @DependencyEndpoint
        public var verifyCodeWithWindow: (
            _ identityId: UUID,
            _ code: String,
            _ window: Int
        ) async throws -> Bool
        
        // MARK: - Backup Code Operations
        
        /// Generate backup codes for recovery
        @DependencyEndpoint
        public var generateBackupCodes: (
            _ identityId: UUID,
            _ count: Int
        ) async throws -> [String]
        
        /// Verify a backup code
        @DependencyEndpoint
        public var verifyBackupCode: (
            _ identityId: UUID,
            _ code: String
        ) async throws -> Bool
        
        /// Get remaining backup codes count
        @DependencyEndpoint
        public var remainingBackupCodes: (
            _ identityId: UUID
        ) async throws -> Int
        
        // MARK: - Management Operations
        
        /// Check if TOTP is enabled for an identity
        @DependencyEndpoint
        public var isEnabled: (
            _ identityId: UUID
        ) async throws -> Bool
        
        /// Disable TOTP for an identity
        @DependencyEndpoint
        public var disable: (
            _ identityId: UUID
        ) async throws -> Void
        
        /// Get TOTP status for an identity
        @DependencyEndpoint
        public var getStatus: (
            _ identityId: UUID
        ) async throws -> Status
        
        // MARK: - QR Code Generation
        
        /// Generate QR code URL for authenticator apps
        @DependencyEndpoint
        public var generateQRCodeURL: (
            _ secret: String,
            _ email: String,
            _ issuer: String
        ) async throws -> URL
        
        // MARK: - Types
        
        public struct SetupData: Codable, Equatable, Sendable {
            public let secret: String // Base32 encoded
            public let qrCodeURL: URL
            public let manualEntryKey: String
            
            public init(
                secret: String,
                qrCodeURL: URL,
                manualEntryKey: String
            ) {
                self.secret = secret
                self.qrCodeURL = qrCodeURL
                self.manualEntryKey = manualEntryKey
            }
        }
        
        public struct Status: Codable, Equatable, Sendable {
            public let isEnabled: Bool
            public let isConfirmed: Bool
            public let backupCodesRemaining: Int
            public let lastUsedAt: Date?
            
            public init(
                isEnabled: Bool,
                isConfirmed: Bool,
                backupCodesRemaining: Int,
                lastUsedAt: Date? = nil
            ) {
                self.isEnabled = isEnabled
                self.isConfirmed = isConfirmed
                self.backupCodesRemaining = backupCodesRemaining
                self.lastUsedAt = lastUsedAt
            }
        }
    }
}

// MARK: - Configuration

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

// MARK: - Errors

extension Identity.MFA.TOTP.Client {
    public enum ClientError: Swift.Error, Equatable {
        case totpNotEnabled
        case totpAlreadyEnabled
        case invalidSecret
        case invalidCode
        case setupNotConfirmed
        case verificationFailed
        case backupCodeGenerationFailed
        case noBackupCodesRemaining
        case configurationError(String)
    }
}

// MARK: - Test Implementation

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
