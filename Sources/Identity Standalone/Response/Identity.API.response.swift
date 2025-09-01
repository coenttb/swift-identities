//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 22/08/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import Identity_Frontend
import Identity_Shared
import Dependencies
import Vapor

extension Identity.API {
    public static func response(
        api: Identity.API,
    ) async throws -> any AsyncResponseEncodable {
        
        @Dependency(\.identity) var configuration
        
        // Apply rate limiting for public endpoints only
        var rateLimitClient: RateLimiter<String>.Client? = nil
        
        if let rateLimiters = configuration.rateLimiters {
            // Only rate limit public endpoints that don't require authentication
            let isPublicEndpoint = switch api {
            case .authenticate(.credentials),
                    .create(.request),
                    .create(.verify),
                    .password(.reset(.request)),
                    .password(.reset(.confirm)):
                true
            default:
                false
            }
            
            if isPublicEndpoint {
                rateLimitClient = try await Identity.API.rateLimit(
                    api: api,
                    rateLimiter: rateLimiters
                )
            }
        }
        
        // Check protection requirements before processing
        // This ensures authenticated routes are properly protected
        do {
            try Identity.API.protect(
                api: api,
                with: Identity.Token.Access.self
            )
        } catch {
            // Record rate limit failure for public endpoints
            if let rateLimitClient {
                await rateLimitClient.recordFailure()
            }
            // If protection fails, return unauthorized
            throw Abort(.unauthorized, reason: "Not authenticated")
        }
        
        let client = configuration.client
        
        // Special handling for logout and logout.all to clear cookies and redirect
        if case .logout = api {
            @Dependency(\.request) var request
            @Dependency(\.logger) var logger
            
            logger.info("[Standalone.logout] Starting logout process")
            
            // Log current cookies before logout
            if let request {
                logger.info("[Standalone.logout] Current request cookies: \(request.cookies.all.map { "\($0.key)=\($0.value.string.prefix(20))..." }.joined(separator: ", "))")
            }
            
            // Call the client logout
            try await client.logout()
            logger.info("[Standalone.logout] Client logout completed")
            
            // Check if this is a browser request (form submission)
            let isFormSubmission = request?.headers["accept"].contains {
                $0.contains("text/html")
            } ?? false
            
            logger.info("[Standalone.logout] Is form submission: \(isFormSubmission)")
            
            if isFormSubmission {
                // Browser request - redirect to logout success page
                let response = try await Response(
                    status: .seeOther,
                    headers: ["Location": configuration.redirect.logoutSuccess().absoluteString]
                )
                logger.info("[Standalone.logout] Created redirect response, expiring cookies")
                // Clear identity cookies
                response.expire(cookies: .identity)
                logger.info("[Standalone.logout] Response cookies after expire: \(response.cookies.all.map { "\($0.key)=\($0.value.string.prefix(20))..., expires=\($0.value.expires?.description ?? "nil"), maxAge=\($0.value.maxAge?.description ?? "nil"), path=\($0.value.path ?? "nil")" }.joined(separator: ", "))")
                
                // Log the actual Set-Cookie headers being sent
                let setCookieHeaders = response.headers[.setCookie]
                logger.info("[Standalone.logout] Set-Cookie headers: \(setCookieHeaders)")
                
                return response
            } else {
                // API request - return JSON
                let response = Response.success(true)
                logger.info("[Standalone.logout] Created JSON response, expiring cookies")
                // Clear identity cookies
                response.expire(cookies: .identity)
                logger.info("[Standalone.logout] Response cookies after expire: \(response.cookies.all.map { "\($0.key)=\($0.value.string.prefix(20))..., expires=\($0.value.expires?.description ?? "nil"), path=\($0.value.path ?? "nil")" }.joined(separator: ", "))")
                return response
            }
        }
        
        // Similar handling for logout.all
        if case .logout(.all) = api {
            @Dependency(\.request) var request
            @Dependency(\.logger) var logger
            
            logger.info("[Standalone.logout.all] Starting logout.all process")
            
            // Log current cookies before logout
            if let request {
                logger.info("[Standalone.logout.all] Current request cookies: \(request.cookies.all.map { "\($0.key)=\($0.value.string.prefix(20))..." }.joined(separator: ", "))")
            }
            
            // Call the client logout.all
            try await client.logout.all()
            logger.info("[Standalone.logout.all] Client logout.all completed - all sessions invalidated")
            
            // Check if this is a browser request (form submission)
            let isFormSubmission = request?.headers["accept"].contains {
                $0.contains("text/html")
            } ?? false
            
            logger.info("[Standalone.logout.all] Is form submission: \(isFormSubmission)")
            
            if isFormSubmission {
                // Browser request - redirect to logout success page
                let response = try await Response(
                    status: .seeOther,
                    headers: ["Location": configuration.redirect.logoutSuccess().absoluteString]
                )
                logger.info("[Standalone.logout.all] Created redirect response, expiring cookies")
                // Clear identity cookies since current session is now invalid
                response.expire(cookies: .identity)
                logger.info("[Standalone.logout.all] Response cookies after expire: \(response.cookies.all.map { "\($0.key)=\($0.value.string.prefix(20))..., expires=\($0.value.expires?.description ?? "nil"), path=\($0.value.path ?? "nil")" }.joined(separator: ", "))")
                return response
            } else {
                // API request - return JSON
                let response = Response.success(true)
                logger.info("[Standalone.logout.all] Created JSON response, expiring cookies")
                // Clear identity cookies since current session is now invalid
                response.expire(cookies: .identity)
                logger.info("[Standalone.logout.all] Response cookies after expire: \(response.cookies.all.map { "\($0.key)=\($0.value.string.prefix(20))..., expires=\($0.value.expires?.description ?? "nil"), path=\($0.value.path ?? "nil")" }.joined(separator: ", "))")
                return response
            }
        }
        
        // Handle MFA requests directly in Standalone (has backend access)
        if case .mfa(let mfaAPI) = api {
            do {
                // Record the attempt BEFORE the actual operation
                if let rateLimitClient {
                    await rateLimitClient.recordAttempt()
                }
                
                let response = try await handleMFAAPI(
                    mfaAPI,
                    client: client,
                    router: configuration.router
                )
                
                // Record rate limit success
                if let rateLimitClient {
                    await rateLimitClient.recordSuccess()
                }
                
                return response
            } catch {
                // Record rate limit failure
                if let rateLimitClient {
                    await rateLimitClient.recordFailure()
                }
                throw error
            }
        }
        
        // Delegate to Frontend with the configuration (which now includes the client)
        do {
            // Record the attempt BEFORE the actual operation
            if let rateLimitClient {
                await rateLimitClient.recordAttempt()
            }
            
            let response = try await Identity.Frontend.response(
                api: api,
                client: client,
                router: configuration.router,
                cookies: configuration.cookies,
                redirect: configuration.redirect
            )
            
            // Record rate limit success for public endpoints
            if let rateLimitClient {
                await rateLimitClient.recordSuccess()
            }
            
            return response
        } catch {
            // Record rate limit failure for public endpoints
            if let rateLimitClient {
                await rateLimitClient.recordFailure()
            }
            
            // Special handling for MFA Required - this is not an error, it's part of the flow
            if let mfaRequired = error as? Identity.Authentication.MFARequired {
                @Dependency(\.logger) var logger
                logger.info("MFA required during authentication - returning MFA challenge")
                
                // Return the MFA challenge response
                let responseData: [String: Any] = [
                    "mfaRequired": true,
                    "sessionToken": mfaRequired.sessionToken,
                    "availableMethods": mfaRequired.availableMethods.map { $0.rawValue },
                    "attemptsRemaining": mfaRequired.attemptsRemaining,
                    "expiresAt": mfaRequired.expiresAt.timeIntervalSince1970
                ]
                
                return try Response.json(success: true, data: responseData)
            }
            
            // Enhanced error response for authentication failures
            if case .authenticate(.credentials) = api {
                // Get updated attempts after failure
                var updatedAttemptsRemaining: Int? = nil
                if let rateLimiters = configuration.rateLimiters,
                   case .authenticate(.credentials(let credentials)) = api {
                    let result = await rateLimiters.credentials.checkLimit(credentials.username)
                    updatedAttemptsRemaining = result.remainingAttempts
                }
                
                // Create enhanced error response for authentication failures
                if let abortError = error as? Abort {
                    let errorCode: String
                    let userMessage: String
                    
                    switch abortError.status {
                    case .unauthorized:
                        errorCode = "INVALID_CREDENTIALS"
                        userMessage = "Invalid email or password"
                    case .tooManyRequests:
                        errorCode = "RATE_LIMIT"
                        userMessage = "Too many attempts. Please try again later."
                    default:
                        errorCode = "AUTH_ERROR"
                        userMessage = "Authentication failed"
                    }
                    
                    struct ErrorResponse: Codable, Vapor.Content {
                        let success: Bool
                        let error: ErrorDetail
                        let attemptsRemaining: Int?
                        let retryAfter: Int?
                        
                        struct ErrorDetail: Codable {
                            let code: String
                            let message: String
                        }
                    }
                    
                    let retryAfterValue: Int? = abortError.status == .tooManyRequests
                    ? abortError.headers.first(name: "Retry-After").flatMap { Int($0) } ?? 60
                    : nil
                    
                    let errorResponse = ErrorResponse(
                        success: false,
                        error: .init(code: errorCode, message: userMessage),
                        attemptsRemaining: updatedAttemptsRemaining,
                        retryAfter: retryAfterValue
                    )
                    
                    let response = Response(status: abortError.status)
                    try response.content.encode(errorResponse)
                    return response
                }
            }
            
            throw error
        }
        
    }
    
    
    
    
    private static func handleMFAAPI(
        _ mfa: Identity.API.MFA,
        client: Identity.Client,
        router: AnyParserPrinter<URLRequestData, Identity.Route>
    ) async throws -> any AsyncResponseEncodable {
        guard let mfaClient = client.mfa else {
            throw Abort(.notImplemented, reason: "MFA is not configured")
        }
        
        switch mfa {
        case .totp(let totp):
            guard let totpClient = mfaClient.totp else {
                throw Abort(.notImplemented, reason: "TOTP is not configured")
            }
            
            switch totp {
            case .setup:
                // This is handled by the view layer
                throw Abort(.badRequest, reason: "TOTP setup should be initiated through the view")
                
            case .confirmSetup(let confirm):
                // Confirm TOTP setup and get backup codes
                let backupCodes = try await totpClient.confirmSetup(confirm.code)
                
                // Return JSON with backup codes directly
                return try Response.json(success: true, data: [
                    "backupCodes": backupCodes,
                    "message": "TOTP setup successful"
                ])
                
            case .verify(let verify):
                // Verify TOTP during login
                let authResponse = try await totpClient.verify(
                    verify.code,
                    verify.sessionToken
                )
                
                // Return success with authentication tokens
                return Response.success(true)
                    .withTokens(for: authResponse)
                
            case .disable(let disable):
                // Disable TOTP
                try await totpClient.disable(disable.reauthorizationToken)
                return Response.success(true)
            }
            
        case .sms:
            throw Abort(.notImplemented, reason: "SMS MFA is not yet implemented")
            
        case .email:
            throw Abort(.notImplemented, reason: "Email MFA is not yet implemented")
            
        case .webauthn:
            throw Abort(.notImplemented, reason: "WebAuthn MFA is not yet implemented")
            
        case .backupCodes:
            throw Abort(.notImplemented, reason: "Backup codes are not yet implemented")
            
        case .status:
            // Get MFA status
            let statusClient = mfaClient.status
            let configuredMethods = try await statusClient.configured()
            return Response.success(true, data: configuredMethods)
            
        case .verify(let verify):
            // General MFA verification endpoint
            // Routes to the appropriate method handler based on the method type
            switch verify.method {
            case .totp:
                guard let totpClient = mfaClient.totp else {
                    throw Abort(.notImplemented, reason: "TOTP is not configured")
                }
                let authResponse = try await totpClient.verify(
                    verify.code,
                    verify.sessionToken
                )
                
                @Dependency(\.request) var request
                @Dependency(\.identity) var configuration
                
                // Check if this is a browser request (form submission)
                let isFormSubmission = request?.headers["accept"].contains {
                    $0.contains("text/html")
                } ?? false
                
                // Extract identity ID from the authentication response
                let jwt = try JWT.parse(from: authResponse.accessToken)
                let accessToken = try Identity.Token.Access(jwt: jwt)
                let identityId = accessToken.identityId
                
                if isFormSubmission {
                    // Browser request - redirect to dashboard after successful MFA
                    let response = try await Response(
                        status: .seeOther,
                        headers: ["Location": configuration.redirect.loginSuccess(identityId).absoluteString]
                    )
                    // Set authentication cookies
                    return response.withTokens(for: authResponse)
                } else {
                    // API request - return JSON with tokens
                    return Response.success(true)
                        .withTokens(for: authResponse)
                }
                
            case .backupCode:
                // TODO: Implement backup code verification
                throw Abort(.notImplemented, reason: "Backup code verification not yet implemented")
                
            case .sms, .email, .webauthn:
                throw Abort(.notImplemented, reason: "\(verify.method.displayName) verification not yet implemented")
            }
        }
    }
}
