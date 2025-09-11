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

extension Identity.MFA.Status.Client {
    /// Creates a live backend implementation of the MFA Status client
    public static func live() -> Self {
        @Dependency(\.logger) var logger
        
        return Self(
            get: {
                logger.debug("Getting MFA status")
                
                // Get current identity
                let identity = try await Identity.Record.get(by: .auth)
                
                // Check TOTP status  
                let totpEnabled = await (try? Identity.MFA.TOTP.Record.findByIdentity(identity.id)) != nil
                
                // Check backup codes remaining
                let backupCodesRemaining = (try? await Identity.MFA.BackupCodes.Record.countUnusedByIdentity(identity.id)) ?? 0
                
                let configuredMethods = Identity.MFA.Status.ConfiguredMethods(
                    totp: totpEnabled,
                    sms: false,  // Not implemented yet
                    email: false, // Not implemented yet
                    webauthn: false, // Not implemented yet
                    backupCodesRemaining: backupCodesRemaining
                )
                
                // For now, MFA is optional
                // In production, this could check organization policies, user roles, etc.
                let isRequired = false
                
                return Identity.MFA.Status.Response(
                    configured: configuredMethods,
                    isRequired: isRequired
                )
            },
            challenge: {
                logger.debug("Getting MFA challenge")
                
                // Get current identity
                let identity = try await Identity.Record.get(by: .auth)
                
                // Check configured methods
                var methods = Set<Identity.MFA.Method>()
                
                let totpEnabled = await (try? Identity.MFA.TOTP.Record.findByIdentity(identity.id)) != nil
                if totpEnabled {
                    methods.insert(.totp)
                }
                
                let backupCodesRemaining = (try? await Identity.MFA.BackupCodes.Record.countUnusedByIdentity(identity.id)) ?? 0
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

