import Dependencies
import Foundation
import IdentitiesTypes
import TOTP
import OneTimePasswordShared
import Crypto


extension Identity.MFA.TOTP.Client {
    /// Creates a Backend-specific implementation with direct database access
    package static func backend(
        configuration: Identity.MFA.TOTP.Configuration
    ) -> Self {
        Self(
            generateSecret: {
                // Generate a secret that's compatible with all authenticator apps
                // Use 20 bytes (160 bits) for SHA1 compatibility - RFC recommended
                var randomBytes = [UInt8](repeating: 0, count: 20)
                _ = SecRandomCopyBytes(kSecRandomDefault, 20, &randomBytes)
                let secretData = Data(randomBytes)
                
                // Convert to Base32 - this should work with all authenticators
                let secret = secretData.base32EncodedString()
                    .replacingOccurrences(of: "=", with: "") // Remove padding
                
                @Dependency(\.logger) var logger
                
                let qrCodeURL = try await generateOTPAuthURL(
                    secret: secret,
                    email: "pending@example.com", // Will be replaced during setup
                    issuer: configuration.issuer,
                    configuration: configuration
                )
                let manualEntryKey = Identity.MFA.TOTP.formatManualEntryKey(secret)
                
                logger.debug("TOTP setup data generated")
                
                return SetupData(
                    secret: secret,
                    qrCodeURL: qrCodeURL,
                    manualEntryKey: manualEntryKey
                )
            },
            
            confirmSetup: { identityId, secret, code in
                @Dependency(\.logger) var logger
                logger.debug("TOTP confirmSetup initiated - code: \(code), identityId: \(identityId)")
                
                // Validate inputs
                guard Identity.MFA.TOTP.isValidSecret(secret) else {
                    throw ClientError.invalidSecret
                }
                
                let sanitizedCode = Identity.MFA.TOTP.sanitizeCode(code)
                guard Identity.MFA.TOTP.isValidCode(sanitizedCode) else {
                    throw ClientError.invalidCode
                }
                
                // Create TOTP instance with the secret as-is
                let totp = try createTOTP(
                    secret: secret,
                    configuration: configuration
                )
                
                // Check for debug bypass
                if Identity.MFA.TOTP.isDebugBypassCode(sanitizedCode) {
                    logger.warning("DEBUG: Using bypass code for TOTP setup")
                    Identity.MFA.TOTP.logDebugBypass()
                } else {
                    logger.debug("Validating TOTP code normally")
                    // Verify the code normally
                    let validated = totp.validate(sanitizedCode, window: configuration.verificationWindow)
                    
                    guard validated else {
                        logger.error("TOTP validation failed for confirmSetup - code: \(sanitizedCode)")
                        throw ClientError.invalidCode
                    }
                    logger.debug("TOTP code validated successfully")
                }                
                // Confirm the setup in database
                guard let totpRecord = try await Database.Identity.TOTP.findByIdentity(identityId) else {
                    throw ClientError.totpNotEnabled
                }
                try await totpRecord.confirm()
                logger.notice("TOTP setup confirmed successfully")
            },
            
            verifyCode: { identityId, code in
                // Use the common verification logic with default window
                return try await verifyTOTPCode(
                    identityId: identityId,
                    code: code,
                    window: configuration.verificationWindow,
                    configuration: configuration
                )
            },
            
            verifyCodeWithWindow: { identityId, code, window in
                // Use the common verification logic with custom window
                return try await verifyTOTPCode(
                    identityId: identityId,
                    code: code,
                    window: window,
                    configuration: configuration
                )
            },
            
            generateBackupCodes: { identityId, count in
                let actualCount = count > 0 ? count : configuration.backupCodeCount
                var codes: [String] = []
                
                for _ in 0..<actualCount {
                    let code = generateBackupCode(length: configuration.backupCodeLength)
                    codes.append(code)
                }
                
                // Save backup codes to database
                try await Database.Identity.BackupCode.create(
                    identityId: identityId,
                    codes: codes
                )
                
                return codes
            },
            
            verifyBackupCode: { identityId, code in
                // Use the existing BackupCode verify method
                return try await Database.Identity.BackupCode.verify(
                    identityId: identityId,
                    code: code
                )
            },
            
            remainingBackupCodes: { identityId in
                return try await Database.Identity.BackupCode.countUnusedByIdentity(identityId)
            },
            
            isEnabled: { identityId in
                let totp = try await Database.Identity.TOTP.findConfirmedByIdentity(identityId)
                return totp != nil
            },
            
            disable: { identityId in
                try await Database.Identity.TOTP.deleteForIdentity(identityId)
                try await Database.Identity.BackupCode.deleteForIdentity(identityId)
            },
            
            getStatus: { identityId in
                let totpData = try await Database.Identity.TOTP.findByIdentity(identityId)
                let backupCodesCount = try await Database.Identity.BackupCode.countUnusedByIdentity(identityId)
                
                // Only consider TOTP enabled if it's confirmed
                let isEnabled = (totpData?.isConfirmed ?? false)
                
                return Status(
                    isEnabled: isEnabled,
                    isConfirmed: totpData?.isConfirmed ?? false,
                    backupCodesRemaining: backupCodesCount,
                    lastUsedAt: totpData?.lastUsedAt
                )
            },
            
            generateQRCodeURL: { secret, email, issuer in
                try await generateOTPAuthURL(
                    secret: secret,
                    email: email,
                    issuer: issuer,
                    configuration: configuration
                )
            }
        )
    }
}

// MARK: - Helper Functions

private func createTOTP(
    secret: String,
    configuration: Identity.MFA.TOTP.Configuration
) throws -> TOTP {
    let algorithm: TOTP.Algorithm
    switch configuration.algorithm {
    case .sha1: algorithm = .sha1
    case .sha256: algorithm = .sha256
    case .sha512: algorithm = .sha512
    }
    
    return try TOTP(
        base32Secret: secret,
        timeStep: configuration.timeStep,
        digits: configuration.digits,
        algorithm: algorithm
    )
}

private func generateOTPAuthURL(
    secret: String,
    email: String,
    issuer: String,
    configuration: Identity.MFA.TOTP.Configuration
) async throws -> URL {
    var components = URLComponents()
    components.scheme = "otpauth"
    components.host = "totp"
    components.path = "/\(issuer):\(email)"
    components.queryItems = [
        URLQueryItem(name: "secret", value: secret),
        URLQueryItem(name: "issuer", value: issuer),
        URLQueryItem(name: "algorithm", value: configuration.algorithm.rawValue.uppercased()),
        URLQueryItem(name: "digits", value: String(configuration.digits)),
        URLQueryItem(name: "period", value: String(Int(configuration.timeStep)))
    ]
    
    guard let url = components.url else {
        throw Identity.MFA.TOTP.Client.ClientError.configurationError("Failed to generate QR code URL")
    }
    
    return url
}

private func generateBackupCode(length: Int) -> String {
    let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var code = ""
    for _ in 0..<length {
        let randomIndex = Int.random(in: 0..<characters.count)
        let index = characters.index(characters.startIndex, offsetBy: randomIndex)
        code += String(characters[index])
    }
    return code
}

private func hashBackupCode(_ code: String) throws -> String {
    // Use SHA256 to hash backup codes
    let data = Data(code.utf8)
    let hashed = SHA256.hash(data: data)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

// MARK: - Common Verification Logic

private func verifyTOTPCode(
    identityId: UUID,
    code: String,
    window: Int,
    configuration: Identity.MFA.TOTP.Configuration
) async throws -> Bool {
    // Validate and sanitize the code
    let sanitizedCode = Identity.MFA.TOTP.sanitizeCode(code)
    guard Identity.MFA.TOTP.isValidCode(sanitizedCode) else {
        throw Identity.MFA.TOTP.Client.ClientError.invalidCode
    }
    
    // Get TOTP data
    guard let totpData = try await Database.Identity.TOTP.findByIdentity(identityId) else {
        throw Identity.MFA.TOTP.Client.ClientError.totpNotEnabled
    }
    
    guard totpData.isConfirmed else {
        throw Identity.MFA.TOTP.Client.ClientError.setupNotConfirmed
    }
    
    // Check for debug bypass
    if Identity.MFA.TOTP.isDebugBypassCode(sanitizedCode) {
        Identity.MFA.TOTP.logDebugBypass()
        try await totpData.recordUsage()
        return true
    }
    
    // Get decrypted secret
    let secret = try totpData.decryptedSecret()
    
    // Create TOTP instance
    let totp = try createTOTP(
        secret: secret,
        configuration: configuration
    )
    
    // Verify the code with specified window
    let isValid = totp.validate(sanitizedCode, window: window)
    
    if isValid {
        try await totpData.recordUsage()
    }
    
    return isValid
}
