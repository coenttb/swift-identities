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

extension Identity.Backend.Client.Authenticate {
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
                    guard let identity = try await Database.Identity.verifyPassword(email: email, password: password) else {
                        logger.warning("Login attempt failed: Invalid credentials for email: \(email)")
                        throw Abort(.unauthorized, reason: "Invalid credentials")
                    }

                    guard identity.emailVerificationStatus == .verified else {
                        logger.warning("Login attempt failed: Email not verified for: \(email)")
                        throw Abort(.unauthorized, reason: "Email not verified")
                    }
                    
                    // Check if MFA is enabled for this identity
                    @Dependency(\.defaultDatabase) var database
                    let totpData = try? await Identity_Backend.Database.Identity.TOTP.findConfirmedByIdentity(identity.id)
                    let totpEnabled = totpData != nil
                    
                    if let totpData = totpData {
                        logger.info("MFA check for \(email): TOTP found - id: \(totpData.id), isConfirmed: \(totpData.isConfirmed)")
                    } else {
                        logger.info("MFA check for \(email): No confirmed TOTP found")
                    }
                    
                    if totpEnabled {
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
            token: .init(
                access: { token in
                    @Dependency(\.logger) var logger
                    @Dependency(\.request) var request
                    guard let request else { throw Abort.requestUnavailable }
                    @Dependency(\.tokenClient) var tokenClient
                    @Dependency(\.date) var date

                    do {
                        let payload = try await tokenClient.verifyAccess(token)

                        logger.trace("Access token payload verified", metadata: [
                            "component": "Backend.Authenticate",
                            "identityId": "\(payload.identityId)"
                        ])

                        guard let identity = try await Database.Identity.findById(payload.identityId) else {
                            throw Abort(.unauthorized, reason: "Identity not found")
                        }

                        guard identity.email == payload.email else {
                            throw Abort(.unauthorized, reason: "Identity details have changed")
                        }
                        
                        guard identity.sessionVersion == payload.sessionVersion else {
                            throw Abort(.unauthorized, reason: "Session has been invalidated")
                        }

                        var updatedIdentity = identity
                        updatedIdentity.lastLoginAt = date()
                        try await updatedIdentity.save()

                        request.auth.login(identity)

                        logger.debug("Access token verified", metadata: [
                            "component": "Backend.Authenticate",
                            "operation": "verifyAccessToken",
                            "identityId": "\(identity.id)"
                        ])

                    } catch {
                        logger.warning("Access token verification failed", metadata: [
                            "component": "Backend.Authenticate",
                            "operation": "verifyAccessToken",
                            "error": "\(error)"
                        ])
                        throw Abort(.unauthorized, reason: "Invalid access token")
                    }
                },
                refresh: { token in
                    @Dependency(\.logger) var logger
                    @Dependency(\.request) var request
                    guard let request else { throw Abort.requestUnavailable }
                    @Dependency(\.tokenClient) var tokenClient

                    do {
                        let payload = try await tokenClient.verifyRefresh(token)

                        guard let identity = try await Database.Identity.findById(payload.identityId) else {
                            throw Abort(.unauthorized, reason: "Identity not found")
                        }

                        guard identity.sessionVersion == payload.sessionVersion else {
                            throw Abort(.unauthorized, reason: "Token has been revoked")
                        }

                        logger.debug("Refresh token verified", metadata: [
                            "component": "Backend.Authenticate",
                            "operation": "verifyRefreshToken",
                            "identityId": "\(identity.id)"
                        ])

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

                        return response

                    } catch {
                        logger.warning("Refresh token verification failed", metadata: [
                            "component": "Backend.Authenticate",
                            "operation": "verifyRefreshToken",
                            "error": "\(error)"
                        ])
                        throw Abort(.unauthorized, reason: "Invalid refresh token")
                    }
                }
            ),
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
                    
                    // Update identity last login
                    var updatedIdentity = identity
                    updatedIdentity.lastLoginAt = date()
                    try await updatedIdentity.save()

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
