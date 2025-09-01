//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 07/02/2025.
//

import ServerFoundation
import Vapor

extension RateLimiter {
    package struct Client {
        package let recordAttempt: () async -> Void
        package let recordSuccess: () async -> Void
        package let recordFailure: () async -> Void

        init(limiter: RateLimiter<Key>, key: Key) {
            self.recordAttempt = { await limiter.recordAttempt(key) }
            self.recordSuccess = { await limiter.recordSuccess(key) }
            self.recordFailure = { await limiter.recordFailure(key) }
        }

        // For handling multiple rate limit keys 
        init(attemptAction: @escaping () async -> Void, successAction: @escaping () async -> Void, failureAction: @escaping () async -> Void) {
            self.recordAttempt = attemptAction
            self.recordSuccess = successAction
            self.recordFailure = failureAction
        }
    }
}

extension Vapor.HTTPHeaders {
    public var retryAfter: [String] {
        self["Retry-After"]
    }
}

extension RateLimiter.Client {
    static var empty: Self {
        return .init(
            attemptAction: { },
            successAction: { },
            failureAction: { }
        )
    }

    static func + (
        lhs: Self,
        rhs: Self
    ) -> Self {
        return .init(
            attemptAction: {
                await lhs.recordAttempt()
                await rhs.recordAttempt()
            },
            successAction: {
                await lhs.recordSuccess()
                await rhs.recordSuccess()
            },
            failureAction: {
                await lhs.recordFailure()
                await rhs.recordFailure()
            }
        )
    }
}

public struct RateLimiters: Sendable {
    public var credentials: RateLimiter<String> = RateLimiter<String>(
        windows: [
            .minutes(1, maxAttempts: 5),
            .hours(1, maxAttempts: 20)
        ],
        metricsCallback: { key, result async in
            @Dependency(\.logger) var logger
            if !result.isAllowed {
                logger.warning("Rate limit exceeded 1", metadata: [
                    "component": "RateLimiter",
                    "type": "credentials",
                    "key": "\(key.prefix(3))...\(key.suffix(3))", // Redact middle portion
                    "retryAfter": "\(result.nextAllowedAttempt?.timeIntervalSinceNow ?? 0)"
                ])
            }
        }
    )

    public var tokenAccess: RateLimiter<String> = RateLimiter<String>(
        windows: [
            .minutes(1, maxAttempts: 60),
            .hours(1, maxAttempts: 3000)
        ],
        metricsCallback: { key, result async in
            @Dependency(\.logger) var logger
            if !result.isAllowed {
                logger.warning("Rate limit exceeded", metadata: [
                    "component": "RateLimiter",
                    "type": "tokenAccess",
                    "keyPrefix": "\(key.prefix(6))", // Just show token prefix
                    "retryAfter": "\(result.nextAllowedAttempt?.timeIntervalSinceNow ?? 0)"
                ])
            }
        }
    )

    public var tokenRefresh: RateLimiter<String> = RateLimiter<String>(
        windows: [
            .minutes(1, maxAttempts: 10),
            .hours(1, maxAttempts: 100)
        ],
        metricsCallback: { key, result async in
            @Dependency(\.logger) var logger
            if !result.isAllowed {
                logger.warning("Rate limit exceeded", metadata: [
                    "component": "RateLimiter",
                    "type": "tokenRefresh",
                    "keyPrefix": "\(key.prefix(6))", // Just show token prefix
                    "retryAfter": "\(result.nextAllowedAttempt?.timeIntervalSinceNow ?? 0)"
                ])
            }
        }
    )

    public init(
        credentials: RateLimiter<String>? = nil,
        tokenAccess: RateLimiter<String>? = nil,
        tokenRefresh: RateLimiter<String>? = nil
    ) {
        if let credentials {
            self.credentials = credentials
        }

        if let tokenAccess {
            self.tokenAccess = tokenAccess
        }

        if let tokenRefresh {
            self.tokenRefresh = tokenRefresh
        }
    }
}

extension RateLimiters {
    public var apiKey: RateLimiter<String> { tokenAccess }
    public var logout: RateLimiter<String> { tokenAccess }
    public var reauthorize: RateLimiter<String> { credentials }
    public var createRequest: RateLimiter<String> { credentials }
    public var createVerify: RateLimiter<String> { credentials }
    public var deleteRequest: RateLimiter<String> { tokenAccess }
    public var deleteConfirm: RateLimiter<String> { tokenAccess }
    public var deleteCancel: RateLimiter<String> { tokenAccess }
    public var emailChangeRequest: RateLimiter<String> { credentials }
    public var emailChangeConfirm: RateLimiter<String> { credentials }
    public var passwordResetRequest: RateLimiter<String> { tokenAccess }
    public var passwordResetConfirm: RateLimiter<String> { tokenAccess }
    public var passwordChangeRequest: RateLimiter<String> { credentials }
}
