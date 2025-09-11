import Foundation
import IdentitiesTypes
import Dependencies
import ServerFoundationVapor
import EmailAddress
import JWT

extension Identity.Client.MFA.TOTP {
    /// Creates a live backend implementation of the TOTP client
    public static func live(
        configuration: Identity.MFA.TOTP.Configuration
    ) -> Self {
        @Dependency(\.logger) var logger
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.tokenClient) var tokenClient
        
        // Create TOTP client with Backend implementation
        let totpClient = Identity.MFA.TOTP.Client.backend(
            configuration: configuration
        )
        
        return Self(
            setup: {
                logger.debug("TOTP setup initiated")
                
                // Get current identity
                let identity = try await Database.Identity.get(by: .auth)
                
                // Check if there's an existing unconfirmed TOTP
                if let existingTOTP = try await Database.Identity.TOTP.findByIdentity(identity.id) {
                    if existingTOTP.isConfirmed {
                        // TOTP is already confirmed, can't set up again
                        logger.warning("TOTP already enabled for identity: \(identity.id)")
                        throw Identity.MFA.TOTP.Client.ClientError.totpAlreadyEnabled
                    } else {
                        // Return the existing unconfirmed TOTP secret
                        logger.debug("Using existing unconfirmed TOTP secret for identity")
                        
                        // Get decrypted secret
                        let secret = try existingTOTP.decryptedSecret()
                        
                        // Generate QR code URL with identity email
                        let qrCodeURL = try await totpClient.generateQRCodeURL(
                            secret,
                            identity.email.rawValue,
                            configuration.issuer
                        )
                        
                        // Format manual entry key (groups of 4 for easier manual entry)
                        let manualEntryKey = Identity.MFA.TOTP.formatManualEntryKey(secret)
                        
                        logger.debug("Returning existing TOTP setup")
                        
                        return Identity.MFA.TOTP.SetupResponse(
                            secret: secret,
                            qrCodeURL: qrCodeURL,
                            manualEntryKey: manualEntryKey
                        )
                    }
                }
                
                // Generate new TOTP secret only if none exists
                logger.debug("Generating new TOTP secret")
                let setupData = try await totpClient.generateSecret()
                
                // Generate QR code URL with identity email
                let qrCodeURL = try await totpClient.generateQRCodeURL(
                    setupData.secret,
                    identity.email.rawValue,
                    configuration.issuer
                )
                
                // Save unconfirmed TOTP secret to database
                _ = try await Database.Identity.TOTP.create(
                    identityId: identity.id,
                    secret: setupData.secret,
                    algorithm: configuration.algorithm,
                    digits: configuration.digits,
                    timeStep: Int(configuration.timeStep)
                )
                
                logger.debug("TOTP setup prepared")
                
                return Identity.MFA.TOTP.SetupResponse(
                    secret: setupData.secret,
                    qrCodeURL: qrCodeURL,
                    manualEntryKey: setupData.manualEntryKey
                )
            },
            
            confirmSetup: { code in
                logger.debug("TOTP setup confirmation initiated with code: \(code)")
                
                // Get current identity
                let identity = try await Database.Identity.get(by: .auth)
                
                // Get unconfirmed TOTP data
                guard let totpData = try await Database.Identity.TOTP.findByIdentity(identity.id) else {
                    logger.error("TOTP setup not found for identity")
                    throw Identity.MFA.TOTP.Client.ClientError.totpNotEnabled
                }
                
                // Get decrypted secret
                let secret = try totpData.decryptedSecret()
                logger.debug("Retrieved secret for TOTP confirmation")
                
                // Verify the code
                try await totpClient.confirmSetup(
                    identity.id,
                    secret,
                    code
                )
                
                
                // Generate default backup codes
                let backupCodes = try await totpClient.generateBackupCodes(
                    identity.id,
                    configuration.backupCodeCount
                )
                
                logger.notice("TOTP setup confirmed successfully with \(backupCodes.count) backup codes")
                
                return backupCodes
            },
            
            verify: { code, sessionToken in
                logger.debug("TOTP verification initiated")
                
                // Verify the MFA session token
                let mfaToken = try await tokenClient.verifyMFASession(sessionToken)
                
                // Check if token is valid
                guard mfaToken.isValid else {
                    logger.error("MFA session token is expired or invalid")
                    throw Identity.Backend.AuthenticationError.tokenExpired
                }
                
                // Check if TOTP is an available method
                guard mfaToken.availableMethods.contains(.totp) else {
                    logger.error("TOTP is not an available method for this session")
                    throw Identity.Backend.AuthenticationError.tokenInvalid
                }
                
                let identityId = mfaToken.identityId
                
                // Get identity from database
                guard let identity = try await database.read({ db in
                    return try await Database.Identity
                        .where { $0.id.eq(identityId) }
                        .fetchOne(db)
                }) else {
                    logger.error("Identity not found: \(identityId)")
                    throw Identity.Backend.AuthenticationError.accountNotFound
                }
                
                // Check if the code is a backup code format (8 characters alphanumeric)
                // Backup codes are typically 8 chars, TOTP codes are 6 digits
                let isBackupCodeFormat = code.count == 8 && 
                    code.allSatisfy { $0.isLetter || $0.isNumber }
                
                var isValid = false
                
                if isBackupCodeFormat {
                    // Try verifying as backup code first
                    logger.debug("Attempting backup code verification")
                    isValid = try await totpClient.verifyBackupCode(identityId, code.uppercased())
                    
                    if isValid {
                        logger.notice("Backup code used for identity: \(identityId)")
                        // TODO: Consider sending email notification about backup code usage
                    }
                }
                
                if !isValid {
                    // Verify as TOTP code
                    isValid = try await totpClient.verifyCode(identityId, code)
                }
                
                guard isValid else {
                    logger.warning("Invalid MFA code for identity: \(identityId)")
                    throw Identity.MFA.TOTP.Client.ClientError.invalidCode
                }
                
                // Generate full authentication tokens
                let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
                    identity.id,
                    identity.email,
                    identity.sessionVersion
                )
                
                logger.notice("MFA verification successful")
                
                return Identity.Authentication.Response(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    mfaStatus: .satisfied
                )
            },
            
            disable: { reauthorizationToken in
                logger.debug("TOTP disable initiated")
                
                // Verify reauthorization token
                let reauthToken = try await tokenClient.verifyReauthorization(reauthorizationToken)
                
                guard let identityId = reauthToken.identityId else {
                    logger.error("Invalid reauthorization token: missing identity ID")
                    throw Identity.Backend.AuthenticationError.tokenInvalid
                }
                
                // Disable TOTP
                try await totpClient.disable(identityId)
                
                logger.notice("TOTP disabled successfully")
            }
        )
    }
}
