//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 18/08/2025.
//

import Foundation
import Identity_Shared
import Throttling
import Identity_Frontend

extension RateLimiters {
    public static let `default` = Self(
        credentials: RateLimiter<String>(
            windows: [
                .minutes(1, maxAttempts: 5),   // 5 attempts per minute (reasonable for user typos)
                .minutes(15, maxAttempts: 15), // 15 attempts per 15 minutes
                .hours(1, maxAttempts: 30)     // 30 attempts per hour
            ],
            metricsCallback: { key, result async in
                @Dependency(\.logger) var logger
                if !result.isAllowed {
                    logger.warning("Rate limit exceeded", metadata: [
                        "component": "Demo",
                        "operation": "login/registration",
                        "key": "\(key)"
                    ])
                }
            }
        ),
        tokenAccess: nil,  // Not needed for Standalone (internal use only)
        tokenRefresh: nil  // Not needed for Standalone (internal use only)
    )
}
