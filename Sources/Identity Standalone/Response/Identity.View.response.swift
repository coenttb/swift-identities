//
//  Identity.Standalone.View.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import Identity_Frontend
import Identity_Backend
import Identity_Views
import Dependencies
import CoenttbHTML
import Coenttb_Web

extension Identity.View {
    /// Handles view rendering for standalone identity management.
    ///
    /// Composes Frontend handlers with backend-enhanced functionality.
    public static func standaloneResponse(
        view: Identity.View
    ) async throws -> any AsyncResponseEncodable {
        
        @Dependency(\.identity) var configuration
        @Dependency(\.identity.client) var client
        @Dependency(\.identity.router) var router
        @Dependency(\.request) var request
        
        // Check authentication requirements
        try await Identity.Frontend.protect(
            view: view,
            router: router
        )
        
        // Handle views with special Standalone logic
        switch view {
        case .delete:
            // Check for status query parameter first
            let statusParam = request?.url.query?.split(separator: "&")
                .compactMap { param -> String? in
                    let parts = param.split(separator: "=", maxSplits: 1)
                    guard parts.count == 2, parts[0] == "status" else { return nil }
                    return String(parts[1])
                }
                .first
            
            if let statusParam = statusParam {
                switch statusParam {
                case "cancelled":
                    return try await Identity.Frontend.htmlDocument(
                        for: view,
                        title: "Delete Account",
                        description: "Delete your account",
                        configuration: configuration
                    ) {
                        Identity.Deletion.Cancelled.View(
                            homeHref: configuration.navigation.home
                        )
                    }
                case "confirmed":
                    return try await Identity.Frontend.htmlDocument(
                        for: view,
                        title: "Delete Account",
                        description: "Delete your account",
                        configuration: configuration
                    ) {
                        Identity.Deletion.Confirm.View(
                            redirectURL: configuration.navigation.home
                        )
                    }
                default:
                    break // Fall through to normal status check
                }
            }
            
            // Check deletion status from backend
            if let deletionStatus = try? await client.delete.status() {
                switch deletionStatus.status {
                case .pending, .awaitingGracePeriod:
                    return try await Identity.Frontend.htmlDocument(
                        for: view,
                        title: "Delete Account",
                        description: "Delete your account",
                        configuration: configuration
                    ) {
                        Identity.Deletion.Pending.View(
                            daysRemaining: deletionStatus.daysRemaining ?? 7,
                            cancelAction: router.url(for: .api(.delete(.cancel))),
                            confirmAction: router.url(for: .api(.delete(.confirm))),
                            homeHref: configuration.navigation.home
                        )
                    }
                case .readyForDeletion:
                    // Grace period expired, ready for final confirmation
                    return try await Identity.Frontend.htmlDocument(
                        for: view,
                        title: "Delete Account",
                        description: "Delete your account",
                        configuration: configuration
                    ) {
                        Identity.Deletion.Pending.View(
                            daysRemaining: 0,
                            cancelAction: router.url(for: .api(.delete(.cancel))),
                            confirmAction: router.url(for: .api(.delete(.confirm))),
                            homeHref: configuration.navigation.home
                        )
                    }
                case .cancelled:
                    // Show initial request form if previously cancelled
                    return try await Identity.Deletion.response(configuration: configuration)
                }
            
            } else {
                // No pending deletion, use Delete handler
                return try await Identity.Deletion.response(configuration: configuration)
            }
            
        case .mfa(let mfa):
            // Handle MFA views with backend access
            return try await handleMFAView(mfa: mfa, configuration: configuration)
            
        case .create(let create):
            return try await Identity.Creation.response(
                view: create,
                configuration: configuration
            )
            
        case .authenticate(let authenticate):
            return try await Identity.Authentication.response(
                view: authenticate,
                configuration: configuration
            )
            
        case .logout:
            return try await Identity.Logout.response(
                client: configuration.client,
                redirect: configuration.redirect
            )
            
        case .email(let email):
            return try await Identity.Email.response(
                view: email,
                configuration: configuration
            )
            
        case .password(let password):
            return try await Identity.Password.response(
                view: password,
                configuration: configuration
            )
        }
    }
    
    /// Handles MFA-specific views that require backend access.
    private static func handleMFAView(
        mfa: Identity.MFA.View,
        configuration: Identity.Standalone.Configuration
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(\.identity.client) var client
        @Dependency(\.identity.router) var router
        @Dependency(\.request) var request
        
        switch mfa {
        case .totp(let totp):
            switch totp {
            case .setup:
                // Generate TOTP setup data
                guard let totpClient = client.mfa?.totp else {
                    throw Abort(.notImplemented, reason: "TOTP is not configured")
                }
                
                let setupData = try await totpClient.setup()
                
                return try await Identity.Frontend.htmlDocument(
                    for: .mfa(mfa),
                    title: "Set Up Two-Factor Authentication",
                    description: "Manage two-factor authentication",
                    configuration: configuration
                ) {
                    Identity.MFA.TOTP.Setup.View(
                        qrCodeURL: setupData.qrCodeURL,
                        secret: setupData.secret,
                        manualEntryKey: setupData.manualEntryKey,
                        confirmAction: router.url(for: .api(.mfa(.totp(.confirmSetup)))),
                        cancelHref: configuration.navigation.home
                    )
                }
                
            case .confirmSetup:
                // This is typically handled by API, but we can show a confirmation view
                return try await Identity.Frontend.htmlDocument(
                    for: .mfa(mfa),
                    title: "Confirm TOTP Setup",
                    description: "Manage two-factor authentication",
                    configuration: configuration
                ) {
                    div {
                        h2 { "Two-Factor Authentication Enabled" }
                            .class("text-2xl font-bold mb-4 text-center")
                        
                        div {
                            div {
                                "✓"
                            }
                            .fontSize(.rem(3))
                            .color(.green)
                            .textAlign(.center)
                            .marginBottom(.rem(1))
                        }
                        
                        p {
                            HTMLText("Your two-factor authentication has been successfully enabled.")
                        }
                        .textAlign(.center)
                        .marginBottom(.rem(2))
                        
                        div {
                            a(href: .url(configuration.navigation.home)) {
                                "Continue to Dashboard"
                            }
                            .class("btn btn-primary")
                        }
                        .textAlign(.center)
                    }
                    .class("bg-gray-50 p-6 rounded-lg")
                }
                
            case .manage:
                // TOTP management page
                guard let statusClient = client.mfa?.status else {
                    throw Abort(.notImplemented, reason: "MFA is not configured")
                }
                
                let configuredMethods = try await statusClient.configured()
                let isEnabled = configuredMethods.totp
                let backupCodesRemaining: Int? = configuredMethods.backupCodesRemaining > 0 ? configuredMethods.backupCodesRemaining : nil
                
                return try await Identity.Frontend.htmlDocument(
                    for: .mfa(mfa),
                    title: "Manage Two-Factor Authentication",
                    description: "Manage two-factor authentication",
                    configuration: configuration
                ) {
                    Identity.MFA.TOTP.Manage.View(
                        isEnabled: isEnabled,
                        backupCodesRemaining: backupCodesRemaining,
                        enableAction: isEnabled ? nil : router.url(for: .view(.mfa(.totp(.setup)))),
                        disableAction: isEnabled ? router.url(for: .api(.mfa(.totp(.disable(.init(reauthorizationToken: "")))))) : nil,
                        regenerateBackupCodesAction: isEnabled ? router.url(for: .view(.mfa(.backupCodes(.display)))) : nil,
                        dashboardHref: configuration.navigation.home
                    )
                }
            }
            
        case .verify(let challenge):
            // MFA verification during login
            // Create a dummy verify request just to get the URL path
            let dummyVerify = Identity.API.MFA.Verify(
                sessionToken: "",
                method: .totp,
                code: ""
            )
            // Get the base URL for the verify endpoint
            let fullVerifyURL = router.url(for: .api(.mfa(.verify(dummyVerify))))
            // Create a clean URL with just the path (no query parameters)
            let verifyURL = URL(string: fullVerifyURL.path, relativeTo: fullVerifyURL.baseURL) ?? fullVerifyURL
            
            // Create URL for backup code verification
            let backupCodeURL = router.url(for: .view(.mfa(.backupCodes(.verify(challenge)))))
            
            return try await Identity.Frontend.htmlDocument(
                for: .mfa(mfa),
                title: "Two-Factor Authentication",
                description: "Manage two-factor authentication",
                configuration: configuration
            ) {
                Identity.MFA.TOTP.Verify.View(
                    sessionToken: challenge.sessionToken,
                    verifyAction: fullVerifyURL,
                    useBackupCodeHref: backupCodeURL,
                    cancelHref: router.url(for: .view(.authenticate(.credentials))),
                    attemptsRemaining: challenge.attemptsRemaining
                )
            }
            
        case .manage:
            // General MFA management page
            guard client.mfa?.status != nil
            else {
                // If no MFA methods are configured, show setup prompt
                return try await Identity.Frontend.htmlDocument(
                    for: .mfa(mfa),
                    title: "Security Settings",
                    description: "Manage two-factor authentication",
                    configuration: configuration
                ) {
                    div {
                        h2 { "Two-Factor Authentication" }
                            .class("text-2xl font-bold mb-4")
                        
                        p {
                            HTMLText("Enhance your account security by enabling two-factor authentication.")
                        }
                        .marginBottom(.rem(2))
                        
                        div {
                            a(href: .url(router.url(for: .view(.mfa(.totp(.setup)))))) {
                                "Enable Two-Factor Authentication"
                            }
                            .class("btn btn-success")
                        }
                    }
                    .class("bg-gray-50 p-6 rounded-lg")
                }
            }
            
            // Redirect to TOTP management if configured
            return try await handleMFAView(mfa: .totp(.manage), configuration: configuration)
            
        case .backupCodes(let backupCodesView):
            switch backupCodesView {
            case .display:
                // Check if we have backup codes from TOTP setup or from regeneration
                var backupCodes: [String] = []
                var isRegeneration = false
                
                @Dependency(\.request) var request
                if let request,
                   let codesString = request.session.data["backup_codes"],
                   let codesData = codesString.data(using: .utf8),
                   let codes = try? JSONDecoder().decode([String].self, from: codesData) {
                    // Codes from TOTP setup
                    backupCodes = codes
                    // Clear from session after reading
                    request.session.data["backup_codes"] = nil
                } else {
                    // Regenerating codes
                    guard let backupCodesClient = client.mfa?.backupCodes else {
                        throw Abort(.notImplemented, reason: "Backup codes are not configured")
                    }
                    backupCodes = try await backupCodesClient.regenerate()
                    isRegeneration = true
                }
                
                return try await Identity.Frontend.htmlDocument(
                    for: .mfa(mfa),
                    title: "Backup Codes",
                    description: "Manage two-factor authentication",
                    configuration: configuration
                ) {
                    Identity.MFA.BackupCodes.Display.View(
                        codes: backupCodes,
                        isRegeneration: isRegeneration,
                        dashboardHref: configuration.navigation.home
                    )
                }
                
            case .verify(let challenge):
                // Backup code verification during login
                // Create a dummy verify request just to get the URL path
                let dummyVerify = Identity.API.MFA.Verify(
                    sessionToken: "test",
                    method: .backupCode,
                    code: "test"
                )
                // Get the base URL for the verify endpoint
                let fullVerifyURL = router.url(for: .api(.mfa(.verify(dummyVerify))))
                // Create a clean URL with just the path (no query parameters)
                let verifyURL = URL(string: fullVerifyURL.path, relativeTo: fullVerifyURL.baseURL) ?? fullVerifyURL
                
                // Get backup codes remaining count if available
                var remainingCodes: Int? = nil
                if let backupCodesClient = client.mfa?.backupCodes {
                    do {
                        remainingCodes = try await backupCodesClient.remaining()
                    } catch {
                        // If we can't get the count, just don't show it
                        remainingCodes = nil
                    }
                }
                
                // Create URL for TOTP verification (to go back)
                let totpURL = router.url(for: .view(.mfa(.verify(challenge))))
                
                return try await Identity.Frontend.htmlDocument(
                    for: .mfa(mfa),
                    title: "Use Backup Code",
                    description: "Manage two-factor authentication",
                    configuration: configuration
                ) {
                    Identity.MFA.BackupCodes.Verify.View(
                        sessionToken: challenge.sessionToken,
                        verifyAction: fullVerifyURL,
                        useTotpHref: totpURL,
                        cancelHref: router.url(for: .view(.authenticate(.credentials))),
                        remainingCodes: remainingCodes
                    )
                }
            }
        }
    }
}
