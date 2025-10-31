import Dependencies
import Foundation
import IdentitiesTypes
import TOTP
import OneTimePasswordShared
import Crypto
import Records


extension Identity.MFA.TOTP.Client {
    /// Convenience method that generates secret AND saves initial TOTP record
    /// This combines generateSecret with database persistence using UPSERT
    public func setup() async throws -> SetupData {
        // Get authenticated identity
        let identity = try await Identity.Record.get(by: .auth)
        
        // 1. Generate the secret
        let setupData = try await self.generateSecret()
        
        // 2. Save initial TOTP record using UPSERT
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.date) var date
        
        try await db.write { db in
            // Encrypt the secret before storing
            let encryptedSecret = try Identity.MFA.TOTP.Record.encryptSecret(setupData.secret)
            
            
            // Use UPSERT to handle re-setup scenarios gracefully
            // This ensures only one TOTP setup per identity
            try await Identity.MFA.TOTP.Record
                .insert {
                    Identity.MFA.TOTP.Record.Draft(
                        identityId: identity.id,
                        secret: encryptedSecret,
                        isConfirmed: false,
                        algorithm: .sha1,  // Default algorithm, matches configuration
                        digits: 6,
                        timeStep: 30,
                        createdAt: date(),
                        confirmedAt: nil,
                        lastUsedAt: nil,
                        usageCount: 0
                    )
                } onConflict: { cols in
                    cols.identityId
                } doUpdate: { updates, excluded in
                    // When re-setting up TOTP, update everything but reset confirmation
                    updates.secret = excluded.secret
                    updates.isConfirmed = false  // Reset confirmation on re-setup
                    updates.confirmedAt = nil
                    updates.algorithm = excluded.algorithm
                    updates.digits = excluded.digits
                    updates.timeStep = excluded.timeStep
                    updates.createdAt = excluded.createdAt  // Update created time on re-setup
                    updates.lastUsedAt = nil  // Reset usage tracking
                    updates.usageCount = 0
                }
                .execute(db)
        }
        
        return setupData
    }
    
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
                    email: .init("pending@example.com"), // Will be replaced during setup
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
                // Confirm the setup in database with explicit operations
                @Dependency(\.defaultDatabase) var db
                @Dependency(\.date) var date
                
                try await db.write { db in
                    // Find and confirm in single transaction
                    guard let totpRecord = try await Identity.MFA.TOTP.Record
                        .findByIdentity(identityId)
                        .fetchOne(db) else {
                        throw ClientError.totpNotEnabled
                    }
                    
                    try await Identity.MFA.TOTP.Record
                        .where { $0.id.eq(totpRecord.id) }
                        .update { totp in
                            totp.isConfirmed = true
                            totp.confirmedAt = date()
                        }
                        .execute(db)
                }
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
            verify: { code, sessionToken in
                @Dependency(\.logger) var logger
                @Dependency(\.tokenClient) var tokenClient
                @Dependency(\.defaultDatabase) var database
                
                logger.debug("TOTP MFA verification initiated")
                
                // 1. Verify the MFA session token
                let mfaToken = try await tokenClient.verifyMFASession(sessionToken)
                
                // Check if token is valid
                guard mfaToken.isValid else {
                    logger.error("MFA session token is expired or invalid")
                    throw Identity.Authentication.Error.tokenExpired
                }
                
                let identityId = mfaToken.identityId
                
                // 2. Get identity from database
                guard let identity = try await database.read({ db in
                    try await Identity.Record
                        .where { $0.id.eq(identityId) }
                        .fetchOne(db)
                }) else {
                    logger.error("Identity not found: \(identityId)")
                    throw Identity.Authentication.Error.accountNotFound
                }
                
                // 3. Verify the TOTP code using existing verification logic
                let isValid = try await verifyTOTPCode(
                    identityId: identityId,
                    code: code,
                    window: configuration.verificationWindow,
                    configuration: configuration
                )
                
                guard isValid else {
                    logger.warning("Invalid TOTP code for identity: \(identityId)")
                    throw Identity.MFA.TOTP.Client.ClientError.invalidCode
                }
                
                logger.notice("TOTP verified successfully for identity: \(identityId)")
                
                // 4. Generate full authentication tokens
                let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
                    identity.id,
                    identity.email,
                    identity.sessionVersion
                )
                
                // 5. Return authentication response
                return Identity.Authentication.Response(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    mfaStatus: .satisfied
                )
            },
            generateBackupCodes: { identityId, count in
                let actualCount = count > 0 ? count : configuration.backupCodeCount
                var codes: [String] = []
                
                for _ in 0..<actualCount {
                    let code = generateBackupCode(length: configuration.backupCodeLength)
                    codes.append(code)
                }
                
                // Save backup codes to database with explicit operations
                @Dependency(\.defaultDatabase) var db
                
                try await db.write { [codes] db in
                    // Delete existing codes
                    try await Identity.MFA.BackupCodes.Record
                        .delete()
                        .where { $0.identityId.eq(identityId) }
                        .execute(db)

                    // Hash codes once before storing
                    let hashedCodes = try codes.map { try Identity.MFA.BackupCodes.Record.hashCode($0) }

                    try await Identity.MFA.BackupCodes.Record
                        .insert {
                            for codeHash in hashedCodes {
                                Identity.MFA.BackupCodes.Record.Draft(
                                    identityId: identityId,
                                    codeHash: codeHash
                                )
                            }
                        }
                        .execute(db)
                }

                return codes
            },
            verifyBackupCode: { identityId, code in
                // Implement atomic verify and mark as used
                @Dependency(\.defaultDatabase) var db
                @Dependency(\.date) var date
                
                return try await db.write { db in
                    let unusedCodes = try await Identity.MFA.BackupCodes.Record
                        .findUnusedByIdentity(identityId)
                        .fetchAll(db)
                    
                    for backupCode in unusedCodes {
                        if try await Identity.MFA.BackupCodes.Record.verifyCode(code, hash: backupCode.codeHash) {
                            // Mark as used in same transaction
                            try await Identity.MFA.BackupCodes.Record
                                .where { $0.id.eq(backupCode.id) }
                                .update { code in
                                    code.isUsed = true
                                    code.usedAt = date()
                                }
                                .execute(db)
                            return true
                        }
                    }
                    return false
                }
            },
            
            remainingBackupCodes: { identityId in
                @Dependency(\.defaultDatabase) var db
                
                return try await db.read { db in
                    try await Identity.MFA.BackupCodes.Record
                        .findUnusedByIdentity(identityId)
                        .fetchCount(db)
                }
            },
            
            isEnabled: { identityId in
                @Dependency(\.defaultDatabase) var db
                
                let count = try await db.read { db in
                    try await Identity.MFA.TOTP.Record
                        .findConfirmedByIdentity(identityId)
                        .fetchCount(db)
                }
                return count > 0
            },
            
            disable: { identityId in
                @Dependency(\.defaultDatabase) var db
                
                try await db.write { db in
                    // Delete TOTP records
                    try await Identity.MFA.TOTP.Record
                        .delete()
                        .where { $0.identityId.eq(identityId) }
                        .execute(db)
                    
                    // Delete backup codes
                    try await Identity.MFA.BackupCodes.Record
                        .delete()
                        .where { $0.identityId.eq(identityId) }
                        .execute(db)
                }
            },
            
            getStatus: { identityId in
                @Dependency(\.defaultDatabase) var db
                
                // Get all status data in single transaction
                return try await db.read { db in
                    let totpData = try await Identity.MFA.TOTP.Record
                        .findByIdentity(identityId)
                        .fetchOne(db)
                    
                    let backupCodesCount = try await Identity.MFA.BackupCodes.Record
                        .findUnusedByIdentity(identityId)
                        .fetchCount(db)
                    
                    // Only consider TOTP enabled if it's confirmed
                    let isEnabled = (totpData?.isConfirmed ?? false)
                    
                    return Status(
                        isEnabled: isEnabled,
                        isConfirmed: totpData?.isConfirmed ?? false,
                        backupCodesRemaining: backupCodesCount,
                        lastUsedAt: totpData?.lastUsedAt
                    )
                }
            },
            
            generateQRCodeURL: { secret, email, issuer in
                try await generateOTPAuthURL(
                    secret: secret,
                    email: .init(email),
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
    email: EmailAddress,
    issuer: String,
    configuration: Identity.MFA.TOTP.Configuration
) async throws -> URL {
    var components = URLComponents()
    components.scheme = "otpauth"
    components.host = "totp"
    components.path = "/\(issuer):\(email.rawValue)"
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
    identityId: Identity.ID,
    code: String,
    window: Int,
    configuration: Identity.MFA.TOTP.Configuration
) async throws -> Bool {
    // Validate and sanitize the code
    let sanitizedCode = Identity.MFA.TOTP.sanitizeCode(code)
    guard Identity.MFA.TOTP.isValidCode(sanitizedCode) else {
        throw Identity.MFA.TOTP.Client.ClientError.invalidCode
    }
    
    @Dependency(\.defaultDatabase) var db
    @Dependency(\.date) var date
    
    // Get TOTP data and verify in transaction
    return try await db.write { db in
        guard let totpData = try await Identity.MFA.TOTP.Record
            .findByIdentity(identityId)
            .fetchOne(db) else {
            throw Identity.MFA.TOTP.Client.ClientError.totpNotEnabled
        }
        
        guard totpData.isConfirmed else {
            throw Identity.MFA.TOTP.Client.ClientError.setupNotConfirmed
        }
        
        // Check for debug bypass
        if Identity.MFA.TOTP.isDebugBypassCode(sanitizedCode) {
            Identity.MFA.TOTP.logDebugBypass()
            
            // Record usage in same transaction
            try await Identity.MFA.TOTP.Record
                .where { $0.id.eq(totpData.id) }
                .update { totp in
                    totp.lastUsedAt = date()
                    totp.usageCount = totp.usageCount + 1
                }
                .execute(db)
            
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
            // Record usage in same transaction
            try await Identity.MFA.TOTP.Record
                .where { $0.id.eq(totpData.id) }
                .update { totp in
                    totp.lastUsedAt = date()
                    totp.usageCount = totp.usageCount + 1
                }
                .execute(db)
        }
        
        return isValid
    }
}
