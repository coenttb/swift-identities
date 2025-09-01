//
//  Identity.Backend.Client.MFA.BackupCodes.live.swift
//  coenttb-identities
//
//  Backup codes management implementation
//

import Dependencies
import Foundation
import IdentitiesTypes
import Vapor

extension Identity.Backend.Client.MFA {
    package static func backupCodesLive(
        configuration: Identity.MFA.TOTP.Configuration
    ) -> Identity.Client.MFA.BackupCodes {
        @Dependency(\.logger) var logger
        @Dependency(\.tokenClient) var tokenClient
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.request) var request
        
        return Identity.Client.MFA.BackupCodes(
            regenerate: {
                logger.debug("Backup codes regeneration initiated")
                
                // Get current identity (requires authentication)
                guard let request else { throw Abort.requestUnavailable }
                guard let identity = request.auth.get(Database.Identity.self) else {
                    logger.error("Not authenticated for backup code regeneration")
                    throw Identity.Backend.AuthenticationError.notAuthenticated
                }
                
                // Check if TOTP is enabled
                guard let totpData = try await Database.Identity.TOTP.findConfirmedByIdentity(identity.id) else {
                    logger.error("TOTP not enabled for identity")
                    throw Identity.MFA.TOTP.Client.ClientError.totpNotEnabled
                }
                
                // Generate new backup codes
                var codes: [String] = []
                for _ in 0..<configuration.backupCodeCount {
                    let code = Database.Identity.BackupCode.generateCode(length: configuration.backupCodeLength)
                    codes.append(code)
                }
                
                // Delete old codes and save new ones
                try await Database.Identity.BackupCode.create(
                    identityId: identity.id,
                    codes: codes
                )
                
                logger.notice("Backup codes regenerated for identity: \(identity.id)")
                
                return codes
            },
            
            verify: { code, sessionToken in
                logger.debug("Backup code verification initiated")
                
                // Verify the MFA session token
                let mfaToken = try await tokenClient.verifyMFASession(sessionToken)
                
                // Check if token is valid
                guard mfaToken.isValid else {
                    logger.error("MFA session token is expired or invalid")
                    throw Identity.Backend.AuthenticationError.tokenExpired
                }
                
                let identityId = mfaToken.identityId
                
                // Get identity from database
                guard let identity = try await database.read({ db in
                    try await Database.Identity
                        .where { $0.id.eq(identityId) }
                        .fetchOne(db)
                }) else {
                    logger.error("Identity not found: \(identityId)")
                    throw Identity.Backend.AuthenticationError.accountNotFound
                }
                
                // Verify the backup code
                let isValid = try await Database.Identity.BackupCode.verify(
                    identityId: identityId,
                    code: code.uppercased()
                )
                
                guard isValid else {
                    logger.warning("Invalid backup code for identity: \(identityId)")
                    throw Identity.MFA.TOTP.Client.ClientError.invalidCode
                }
                
                logger.notice("Backup code verified successfully for identity: \(identityId)")
                
                // Generate full authentication tokens
                let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
                    identity.id,
                    identity.email,
                    identity.sessionVersion
                )
                
                return Identity.Authentication.Response(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    mfaStatus: .satisfied
                )
            },
            
            remaining: {
                logger.debug("Fetching remaining backup codes count")
                
                // Get current identity (requires authentication)
                guard let request else { throw Abort.requestUnavailable }
                guard let identity = request.auth.get(Database.Identity.self) else {
                    logger.error("Not authenticated for backup code count")
                    throw Identity.Backend.AuthenticationError.notAuthenticated
                }
                
                let count = try await Database.Identity.BackupCode.countUnusedByIdentity(identity.id)
                
                logger.debug("Remaining backup codes for identity \(identity.id): \(count)")
                
                return count
            }
        )
    }
}
