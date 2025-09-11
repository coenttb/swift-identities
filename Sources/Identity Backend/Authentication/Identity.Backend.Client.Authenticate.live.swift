//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 12/09/2024.
//

import ServerFoundation
import ServerFoundationVapor
import IdentitiesTypes
import JWT
import Dependencies
import EmailAddress

extension Identity.Authentication.Client {
    package static func live(
    ) -> Self {
        @Dependency(\.logger) var logger

        return .init(
            credentials: { username, password in
                let email: EmailAddress = try .init(username)
                
                @Dependency(\.request) var request
                guard let request else { throw Abort.requestUnavailable }
                @Dependency(\.date) var date

                do {
                    // Use cached and optimized single query for authentication
                    guard let authData = try await Database.Identity.verifyPasswordOptimized(email: email, password: password) else {
                        logger.warning("Login attempt failed: Invalid credentials for email: \(email)")
                        throw Abort(.unauthorized, reason: "Invalid credentials")
                    }
                    
                    let identity = authData.identity

                    guard identity.emailVerificationStatus == .verified else {
                        logger.warning("Login attempt failed: Email not verified for: \(email)")
                        throw Abort(.unauthorized, reason: "Email not verified")
                    }
                    
                    // MFA status already included in authData
                    if authData.totpEnabled {
                        logger.info("MFA check for \(email): TOTP enabled")
                    } else {
                        logger.info("MFA check for \(email): No TOTP configured")
                    }
                    
                    if authData.totpEnabled {
                        // Generate MFA session token instead of full authentication
                        @Dependency(\.tokenClient) var tokenClient
                        let sessionToken = try await tokenClient.generateMFASession(
                            identity.id,
                            identity.sessionVersion,
                            3, // attempts remaining
                            [.totp] // available methods
                        )
                        
                        logger.notice("MFA required for email: \(email) - throwing MFARequired error")
                        
                        // Return MFA challenge response
                        throw Identity.Authentication.MFARequired(
                            sessionToken: sessionToken,
                            availableMethods: [.totp],
                            attemptsRemaining: 3
                        )
                    }

                    @Dependency(\.tokenClient) var tokenClient
                    let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
                        identity.id,
                        identity.email,
                        identity.sessionVersion
                    )
                    
                    let response = Identity.Authentication.Response(
                        accessToken: .init(accessToken),
                        refreshToken: .init(refreshToken)
                    )

                    request.auth.login(identity)
                    logger.notice("Login successful for email: \(email)")

                    return response

                } catch let mfaRequired as Identity.Authentication.MFARequired {
                    // Re-throw MFA required - this is not an error, it's part of the flow
                    logger.info("Re-throwing MFA required for propagation")
                    throw mfaRequired
                } catch {
                    logger.warning("Login attempt failed: \(error)")
                    throw Abort(.unauthorized, reason: "Invalid credentials")
                }
            },
            apiKey: { apiKeyString in
                @Dependency(\.request) var request
                @Dependency(\.logger) var logger
                @Dependency(\.date) var date
                @Dependency(\.tokenClient) var tokenClient
                guard let request else { throw Abort.requestUnavailable }

                do {
                    guard let apiKey = try await IdentityApiKey.findByKey(apiKeyString) else {
                        logger.warning("API key authentication failed", metadata: [
                            "component": "Backend.Authenticate",
                            "operation": "apiKeyAuth",
                            "reason": "keyNotFound"
                        ])
                        throw Abort(.unauthorized, reason: "Invalid API key")
                    }

                    guard !apiKey.isExpired else {
                        var mutableApiKey = apiKey
                        try await mutableApiKey.deactivate()
                        throw Abort(.unauthorized, reason: "API key has expired")
                    }

                    guard let identity = try await Database.Identity.findById(apiKey.identityId) else {
                        throw Abort(.unauthorized, reason: "Associated identity not found")
                    }

                    // Update API key last used
                    var mutableApiKey = apiKey
                    try await mutableApiKey.updateLastUsed()
                    
                    // Update identity last login using optimized method
                    try await Database.Identity.updateLastLogin(id: identity.id)

                    let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
                        identity.id,
                        identity.email,
                        identity.sessionVersion
                    )
                    
                    let response = Identity.Authentication.Response(
                        accessToken: .init(accessToken),
                        refreshToken: .init(refreshToken)
                    )

                    request.auth.login(identity)

                    logger.notice("API key authentication successful for identity: \(identity.id)")

                    return response
                } catch {
                    logger.error("Unexpected error during api key verification: \(error.localizedDescription)")
                    throw Abort(.internalServerError, reason: "Unexpected error during api key verification")
                }
            }
        )
    }
}
