//
//  Identity.Backend.Client.MFA.Status.live.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import IdentitiesTypes
import Dependencies
import ServerFoundationVapor

extension Identity.Client.MFA.Status {
    /// Creates a live backend implementation of the MFA Status client
    public static func live() -> Self {
        @Dependency(\.logger) var logger
        
        return Self(
            configured: {
                logger.debug("Checking configured MFA methods")
                
                // Get current identity
                let identity = try await Identity_Backend.Database.Identity.get(by: .auth)
                
                // Check TOTP status  
                let totpEnabled = await (try? Identity_Backend.Database.Identity.TOTP.findByIdentity(identity.id)) != nil
                
                // Check backup codes remaining
                let backupCodesRemaining = (try? await Identity_Backend.Database.Identity.BackupCode.countUnusedByIdentity(identity.id)) ?? 0
                
                return Identity.MFA.ConfiguredMethods(
                    totp: totpEnabled,
                    sms: false,  // Not implemented yet
                    email: false, // Not implemented yet
                    webauthn: false, // Not implemented yet
                    backupCodesRemaining: backupCodesRemaining
                )
            },
            isRequired: {
                // For now, MFA is optional
                // In production, this could check organization policies, user roles, etc.
                return false
            },
            challenge: {
                logger.debug("Getting MFA challenge")
                
                // Get current identity
                let identity = try await Identity_Backend.Database.Identity.get(by: .auth)
                
                // Check configured methods
                var methods = Set<Identity.MFA.Method>()
                
                let totpEnabled = await (try? Identity_Backend.Database.Identity.TOTP.findByIdentity(identity.id)) != nil
                if totpEnabled {
                    methods.insert(.totp)
                }
                
                let backupCodesRemaining = (try? await Identity_Backend.Database.Identity.BackupCode.countUnusedByIdentity(identity.id)) ?? 0
                if backupCodesRemaining > 0 {
                    methods.insert(.backupCode)
                }
                
                // Generate session token for MFA
                @Dependency(\.tokenClient) var tokenClient
                let sessionToken = try await tokenClient.generateMFASession(
                    identity.id,
                    identity.sessionVersion,
                    3, // attempts remaining
                    Array(methods) // available methods
                )
                
                return Identity.MFA.Challenge(
                    sessionToken: sessionToken,
                    availableMethods: methods,
                    expiresAt: Date().addingTimeInterval(300), // 5 minutes
                    attemptsRemaining: 3
                )
            }
        )
    }
}

