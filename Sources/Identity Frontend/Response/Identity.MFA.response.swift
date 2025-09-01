////
////  Identity.MFA.response.swift
////  coenttb-identities
////
////  Created by Coen ten Thije Boonkkamp on 22/08/2025.
////
//
//import ServerFoundationVapor
//import Identities
//import CoenttbHTML
//import Coenttb_Web
//import Identity_Views
//import Dependencies
//import Language
//
//// MARK: - Response Dispatcher
//
//extension Identity.MFA {
//    /// Dispatches MFA view requests to appropriate handlers.
//    public static func response(
//        view: Identity.MFA.View,
//        configuration: Identity.Frontend.Configuration
//    ) async throws -> any AsyncResponseEncodable {
//        switch view {
//        case .verify(let challenge):
//            return try await handleVerify(challenge: challenge, configuration: configuration)
//            
//        case .totp(let totp):
//            // These require backend access - handled differently in Standalone
//            return try await handleBackendRequired(mfa: .totp(totp), configuration: configuration)
//            
//        case .manage:
//            // Requires backend access - handled differently in Standalone
//            return try await handleBackendRequired(mfa: .manage, configuration: configuration)
//            
//        case .backupCodes(let backupCodes):
//            switch backupCodes {
//            case .verify(let challenge):
//                return try await handleBackupCodeVerify(challenge: challenge, configuration: configuration)
//            case .display:
//                // Requires backend access - handled differently in Standalone
//                return try await handleBackendRequired(mfa: .backupCodes(.display), configuration: configuration)
//            }
//        }
//    }
//}
//
//extension Identity.MFA {
//    // MARK: - MFA Handlers
//    
//    /// Handles MFA verification view during login.
//    public static func handleVerify(
//        challenge: Identity.MFA.URLChallenge,
//        configuration: Identity.Frontend.Configuration
//    ) async throws -> any AsyncResponseEncodable {
//        let router = configuration.router
//        
//        // Create URL for backup code verification
//        let backupCodeURL = router.url(for: .mfa(.view(.backupCodes(.verify(challenge)))))
//        
//        // Create a dummy verify request just to get the URL path
//        let dummyVerify = Identity.API.MFA.Verify(
//            sessionToken: "",
//            method: .totp,
//            code: ""
//        )
//        // Get the base URL for the verify endpoint
//        let fullVerifyURL = router.url(for: .mfa(.api(.verify(dummyVerify))))
//        // Create a clean URL with just the path (no query parameters)
//        let verifyURL = URL(string: fullVerifyURL.path, relativeTo: fullVerifyURL.baseURL) ?? fullVerifyURL
//        
//        return try await Identity.Frontend.htmlDocument(for: .mfa(.verify(challenge)), configuration: configuration) {
//            Identity.MFA.TOTP.Verify.View(
//                sessionToken: challenge.sessionToken,
//                verifyAction: verifyURL,
//                useBackupCodeHref: backupCodeURL,
//                cancelHref: router.url(for: .login),
//                attemptsRemaining: challenge.attemptsRemaining
//            )
//        }
//    }
//    
//    /// Handles backup code verification view during login.
//    public static func handleBackupCodeVerify(
//        challenge: Identity.MFA.URLChallenge,
//        configuration: Identity.Frontend.Configuration
//    ) async throws -> any AsyncResponseEncodable {
//        let router = configuration.router
//        
//        // Create a dummy verify request just to get the URL path
//        let dummyVerify = Identity.API.MFA.Verify(
//            sessionToken: "",
//            method: .backupCode,
//            code: ""
//        )
//        // Get the base URL for the verify endpoint
//        let fullVerifyURL = router.url(for: .mfa(.api(.verify(dummyVerify))))
//        // Create a clean URL with just the path (no query parameters)
//        let verifyURL = URL(string: fullVerifyURL.path, relativeTo: fullVerifyURL.baseURL) ?? fullVerifyURL
//        
//        // Create URL for TOTP verification (to go back)
//        let totpURL = router.url(for: .mfa(.view(.verify(challenge))))
//        
//        return try await Identity.Frontend.htmlDocument(for: .mfa(.backupCodes(.verify(challenge))), configuration: configuration) {
//            Identity.MFA.BackupCodes.Verify.View(
//                sessionToken: challenge.sessionToken,
//                verifyAction: verifyURL,
//                useTotpHref: totpURL,
//                cancelHref: router.url(for: .login),
//                remainingCodes: nil // Frontend doesn't have access to backup codes count
//            )
//        }
//    }
//    
//    /// Handles MFA views that require backend access - returns a placeholder.
//    /// These should be overridden by Standalone implementation.
//    public static func handleBackendRequired(
//        mfa: Identity.MFA.View,
//        configuration: Identity.Frontend.Configuration
//    ) async throws -> any AsyncResponseEncodable {
//        let router = configuration.router
//        
//        // For frontend-only implementations, show a message or redirect
//        return try await Identity.Frontend.htmlDocument(
//            for: .mfa(mfa),
//            title: "Two-Factor Authentication",
//            description: "This feature requires backend access",
//            configuration: configuration
//        ) {
//            div {
//                h2 { "Two-Factor Authentication" }
//                    .class("text-2xl font-bold mb-4")
//                
//                p {
//                    HTMLText("This feature is not available in the current configuration.")
//                }
//                .marginBottom(.rem(2))
//                
//                div {
//                    a(href: .url(configuration.navigation.home)) {
//                        "Return to Home"
//                    }
//                    .class("btn btn-primary")
//                }
//            }
//            .class("bg-gray-50 p-6 rounded-lg")
//        }
//    }
//}
