//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 07/02/2025.
//

import ServerFoundationVapor

extension Identity.API {
    package static func rateLimit(
        api: Identity.API,
        rateLimiter: RateLimiters
    ) async throws -> RateLimiter<String>.Client {

        switch api {
        case .authenticate(let authenticate):
            switch authenticate {
            case .credentials(let credentials):
                // Check rate limit by username/email
                let emailRateLimit = await rateLimiter.credentials.checkLimit(credentials.username)

                guard emailRateLimit.isAllowed
                else {
                    throw Abort(.tooManyRequests, headers: [
                        "Retry-After": "\(Int(emailRateLimit.nextAllowedAttempt?.timeIntervalSinceNow ?? 60))"
                    ])
                }

                // Also check rate limit by IP address if available
                @Dependency(\.request?.realIP) var realIP

                if let clientIP = realIP {
                    let ipRateLimit = await rateLimiter.credentials.checkLimit("ip:\(clientIP)")

                    guard ipRateLimit.isAllowed
                    else {
                        throw Abort(.tooManyRequests, headers: [
                            "Retry-After": "\(Int(ipRateLimit.nextAllowedAttempt?.timeIntervalSinceNow ?? 60))"
                        ])
                    }

                    // Create combined client that tracks both email and IP
                    let usernameClient = RateLimiter<String>.Client(limiter: rateLimiter.credentials, key: credentials.username)
                    let ipClient = RateLimiter<String>.Client(limiter: rateLimiter.credentials, key: "ip:\(clientIP)")
                    return usernameClient + ipClient
                }

                // Fallback to username-only rate limiting (for tests)
                return .init(limiter: rateLimiter.credentials, key: credentials.username)

            case .token(let token):
                switch token {
                case .access(let access):
                    let tokenString = try access.compactSerialization()
                    let rateLimit = await rateLimiter.tokenAccess.checkLimit(tokenString)

                    guard rateLimit.isAllowed
                    else {
                        throw Abort(.tooManyRequests, headers: [
                            "Retry-After": "\(Int(rateLimit.nextAllowedAttempt?.timeIntervalSinceNow ?? 60))"
                        ])
                    }

                    return .init(limiter: rateLimiter.tokenAccess, key: tokenString)

                case .refresh(let refresh):
                    let tokenString = try refresh.compactSerialization()
                    let rateLimit = await rateLimiter.tokenRefresh.checkLimit(tokenString)

                    guard rateLimit.isAllowed
                    else {
                        throw Abort(.tooManyRequests, headers: [
                            "Retry-After": "\(Int(rateLimit.nextAllowedAttempt?.timeIntervalSinceNow ?? 60))"
                        ])
                    }

                    return .init(limiter: rateLimiter.tokenRefresh, key: tokenString)
                }

            case .apiKey(let apiKey):
                let rateLimit = await rateLimiter.apiKey.checkLimit(apiKey.token)

                guard rateLimit.isAllowed
                else {
                    if let nextAttempt = rateLimit.nextAllowedAttempt {
                        throw Abort.rateLimit(delay: nextAttempt.timeIntervalSinceNow)
                    }
                    throw Abort(.tooManyRequests)
                }

                return .init(limiter: rateLimiter.apiKey, key: apiKey.token)
            }

        case .create(let create):
            switch create {
            case .request(let request):

                let emailRateLimit = await rateLimiter.createRequest.checkLimit(request.email)

                guard emailRateLimit.isAllowed else {
                    throw Abort.rateLimit(nextAllowedAttempt: emailRateLimit.nextAllowedAttempt)
                }

                // Get IP address for rate limiting if available
                @Dependency(\.request?.realIP) var realIP

                // For tests where realIP might not be available
                if let clientIP = realIP {
                    let ipRateLimit = await rateLimiter.createRequest.checkLimit("ip:\(clientIP)")

                    guard ipRateLimit.isAllowed else {
                        throw Abort.rateLimit(nextAllowedAttempt: ipRateLimit.nextAllowedAttempt)
                    }

                    // Create combined client that tracks both email and IP
                    let emailClient = RateLimiter<String>.Client(limiter: rateLimiter.createRequest, key: request.email)
                    let ipClient = RateLimiter<String>.Client(limiter: rateLimiter.createRequest, key: "ip:\(clientIP)")

                    return emailClient + ipClient
                }

                // Fallback to email-only rate limiting (for tests)
                return .init(limiter: rateLimiter.createRequest, key: request.email)

            case .verify(let verify):
                let rateLimit = await rateLimiter.createVerify.checkLimit(verify.token)

                guard rateLimit.isAllowed
                else {
                    throw Abort.rateLimit(nextAllowedAttempt: rateLimit.nextAllowedAttempt)
                }

                return .init(limiter: rateLimiter.createVerify, key: verify.token)
            }

        case .delete(let delete):
            @Dependency(\.request) var request
            guard let request else { throw Abort.requestUnavailable }

            let key = request.realIP
            switch delete {
            case .request:
                let rateLimit = await rateLimiter.deleteRequest.checkLimit(key)

                guard rateLimit.isAllowed
                else {
                    throw Abort.rateLimit(nextAllowedAttempt: rateLimit.nextAllowedAttempt)
                }

                return .init(limiter: rateLimiter.deleteRequest, key: key)

            case .confirm:
                let rateLimit = await rateLimiter.deleteConfirm.checkLimit(key)

                guard rateLimit.isAllowed
                else {
                    throw Abort.rateLimit(nextAllowedAttempt: rateLimit.nextAllowedAttempt)
                }

                return .init(limiter: rateLimiter.deleteConfirm, key: key)

            case .cancel:
                let rateLimit = await rateLimiter.deleteCancel.checkLimit(key)

                guard rateLimit.isAllowed
                else {
                    throw Abort.rateLimit(nextAllowedAttempt: rateLimit.nextAllowedAttempt)
                }

                return .init(limiter: rateLimiter.deleteCancel, key: key)
            }

        case .email(let email):
            switch email {
            case .change(let change):
                switch change {
                case .request(let request):
                    // Check rate limit by new email
                    let emailRateLimit = await rateLimiter.emailChangeRequest.checkLimit(request.newEmail)

                    guard emailRateLimit.isAllowed
                    else {
                        throw Abort.rateLimit(nextAllowedAttempt: emailRateLimit.nextAllowedAttempt)
                    }

                    // Also check rate limit by IP address if available
                    @Dependency(\.request?.realIP) var realIP

                    if let clientIP = realIP {
                        let ipRateLimit = await rateLimiter.emailChangeRequest.checkLimit("ip:\(clientIP)")

                        guard ipRateLimit.isAllowed
                        else {
                            throw Abort.rateLimit(nextAllowedAttempt: ipRateLimit.nextAllowedAttempt)
                        }

                        // Create combined client that tracks both email and IP
                        let emailClient = RateLimiter<String>.Client(limiter: rateLimiter.emailChangeRequest, key: request.newEmail)
                        let ipClient = RateLimiter<String>.Client(limiter: rateLimiter.emailChangeRequest, key: "ip:\(clientIP)")
                        return emailClient + ipClient
                    }

                    // Fallback to email-only rate limiting (for tests)
                    return .init(limiter: rateLimiter.emailChangeRequest, key: request.newEmail)

                case .confirm(let confirm):
                    // Check rate limit by token
                    let tokenRateLimit = await rateLimiter.emailChangeConfirm.checkLimit(confirm.token)

                    guard tokenRateLimit.isAllowed
                    else {
                        throw Abort.rateLimit(nextAllowedAttempt: tokenRateLimit.nextAllowedAttempt)
                    }

                    // Also check rate limit by IP address if available
                    @Dependency(\.request?.realIP) var realIP

                    if let clientIP = realIP {
                        let ipRateLimit = await rateLimiter.emailChangeConfirm.checkLimit("ip:\(clientIP)")

                        guard ipRateLimit.isAllowed
                        else {
                            throw Abort.rateLimit(nextAllowedAttempt: ipRateLimit.nextAllowedAttempt)
                        }

                        // Create combined client that tracks both token and IP
                        let tokenClient = RateLimiter<String>.Client(limiter: rateLimiter.emailChangeConfirm, key: confirm.token)
                        let ipClient = RateLimiter<String>.Client(limiter: rateLimiter.emailChangeConfirm, key: "ip:\(clientIP)")
                        return tokenClient + ipClient
                    }

                    // Fallback to token-only rate limiting (for tests)
                    return .init(limiter: rateLimiter.emailChangeConfirm, key: confirm.token)
                }
            }

        case .logout(.current):
            @Dependency(\.request) var request
            guard let request else { throw Abort.requestUnavailable }
            let key = request.realIP
            let rateLimit = await rateLimiter.logout.checkLimit(key)

            guard rateLimit.isAllowed
            else {
                throw Abort.rateLimit(nextAllowedAttempt: rateLimit.nextAllowedAttempt)
            }
            return .init(limiter: rateLimiter.logout, key: key)
            
        case .logout(.all):
            @Dependency(\.request) var request
            guard let request else { throw Abort.requestUnavailable }
            let key = request.realIP
            let rateLimit = await rateLimiter.logout.checkLimit(key)

            guard rateLimit.isAllowed
            else {
                throw Abort.rateLimit(nextAllowedAttempt: rateLimit.nextAllowedAttempt)
            }
            return .init(limiter: rateLimiter.logout, key: key)

        case .password(let password):
            switch password {
            case .reset(let reset):
                switch reset {
                case .request(let request):
                    // Check rate limit by email
                    let emailRateLimit = await rateLimiter.passwordResetRequest.checkLimit(request.email)

                    guard emailRateLimit.isAllowed
                    else {
                        throw Abort.rateLimit(nextAllowedAttempt: emailRateLimit.nextAllowedAttempt)
                    }

                    // Also check rate limit by IP address if available
                    @Dependency(\.request?.realIP) var realIP

                    if let clientIP = realIP {
                        let ipRateLimit = await rateLimiter.passwordResetRequest.checkLimit("ip:\(clientIP)")

                        guard ipRateLimit.isAllowed
                        else {
                            throw Abort.rateLimit(nextAllowedAttempt: ipRateLimit.nextAllowedAttempt)
                        }

                        // Create combined client that tracks both email and IP
                        let emailClient = RateLimiter<String>.Client(limiter: rateLimiter.passwordResetRequest, key: request.email)
                        let ipClient = RateLimiter<String>.Client(limiter: rateLimiter.passwordResetRequest, key: "ip:\(clientIP)")
                        return emailClient + ipClient
                    }

                    // Fallback to email-only rate limiting (for tests)
                    return .init(limiter: rateLimiter.passwordResetRequest, key: request.email)

                case .confirm(let confirm):
                    // Check rate limit by token
                    let tokenRateLimit = await rateLimiter.passwordResetConfirm.checkLimit(confirm.token)

                    guard tokenRateLimit.isAllowed
                    else {
                        throw Abort.rateLimit(nextAllowedAttempt: tokenRateLimit.nextAllowedAttempt)
                    }

                    // Also check rate limit by IP address if available
                    @Dependency(\.request?.realIP) var realIP

                    if let clientIP = realIP {
                        let ipRateLimit = await rateLimiter.passwordResetConfirm.checkLimit("ip:\(clientIP)")

                        guard ipRateLimit.isAllowed
                        else {
                            throw Abort.rateLimit(nextAllowedAttempt: ipRateLimit.nextAllowedAttempt)
                        }

                        // Create combined client that tracks both token and IP
                        let tokenClient = RateLimiter<String>.Client(limiter: rateLimiter.passwordResetConfirm, key: confirm.token)
                        let ipClient = RateLimiter<String>.Client(limiter: rateLimiter.passwordResetConfirm, key: "ip:\(clientIP)")

                        return tokenClient + ipClient
                    }

                    // Fallback to token-only rate limiting (for tests)
                    return .init(limiter: rateLimiter.passwordResetConfirm, key: confirm.token)
                }

            case .change:
                @Dependency(\.request) var request
                guard let request else { throw Abort.requestUnavailable }
                let key = request.realIP
                let rateLimit = await rateLimiter.passwordChangeRequest.checkLimit(key)

                guard rateLimit.isAllowed
                else {
                    throw Abort.rateLimit(nextAllowedAttempt: rateLimit.nextAllowedAttempt)
                }

                return .init(limiter: rateLimiter.passwordChangeRequest, key: key)
            }

        case .reauthorize:
            @Dependency(\.request) var request
            guard let request else { throw Abort.requestUnavailable }
            let key = request.realIP
            let rateLimit = await rateLimiter.reauthorize.checkLimit(key)

            guard rateLimit.isAllowed
            else {
                throw Abort.rateLimit(nextAllowedAttempt: rateLimit.nextAllowedAttempt)
            }
            return .init(limiter: rateLimiter.reauthorize, key: key)
            
        case .mfa:
            // MFA operations use authenticated user's IP for rate limiting
            @Dependency(\.request) var request
            guard let request else { throw Abort.requestUnavailable }
            let key = request.realIP
            
            // Use a general MFA rate limiter - you may want to add specific ones later
            let rateLimit = await rateLimiter.reauthorize.checkLimit(key)
            
            guard rateLimit.isAllowed
            else {
                throw Abort.rateLimit(nextAllowedAttempt: rateLimit.nextAllowedAttempt)
            }
            return .init(limiter: rateLimiter.reauthorize, key: key)
        }
    }
}
