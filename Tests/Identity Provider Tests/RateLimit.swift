//
//  RateLimit.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 02/03/2025.
//

import Identity_Provider
import Identity_Shared
import DependenciesTestSupport
import EmailAddress
import FluentSQLiteDriver
import Foundation
import JWT
import Testing
import Vapor
import VaporTesting

@Suite(
    "Identity Provider Ratelimit Tests",
    .dependency(\.uuid, .incrementing),
    .dependency(\.date, .init(Date.init)),
    .dependency(\.identity.provider.client, .liveTest)
)
struct IdentityProviderRatelimitTests {
    @Test("Test credential authentication rate limiting")
    func testCredentialRateLimiting() async throws {
        try await withTestApp { app in
            let (testEmail, testPassword) = try await setupMockIdentity(app: app)

            // Make requests up to the rate limit (4 requests allowed after setup)
            for i in 1...4 {
                let response = try await app.test(
                    identity: .authenticate(
                        .credentials(
                            .init(
                                username: testEmail,
                                password: testPassword
                            )
                        )
                    )
                )
                #expect(response.status == .ok)
            }

            // Next request should be rate limited
            do {
                let rateLimitResponse = try await app.test(
                    identity: .authenticate(
                        .credentials(
                            .init(
                                username: testEmail,
                                password: testPassword
                            )
                        )
                    )
                )
                #expect(rateLimitResponse.status == .tooManyRequests)
                #expect(rateLimitResponse.headers.retryAfter != nil)
            } catch let error as Abort {
                #expect(error.status == .tooManyRequests)
            }
        }
    }

    @Test("Test account creation rate limiting")
    func testAccountCreationRateLimiting() async throws {
        try await withTestApp { app in
            let baseEmail = "test\(UUID())@example.com"

            // Make requests up to limit from same IP
            for i in 1...5 {
                let email = "\(i)-\(baseEmail)"
                let response = try await app.test(
                    identity: .create(.request(
                        .init(
                            email: email,
                            password: "StrongP@ssw0rd!"
                        )
                    ))
                )
                #expect(response.status == .ok)
            }

            // Next request should be rate limited
            do {
                let rateLimitResponse = try await app.test(
                    identity: .create(.request(
                        .init(
                            email: "last-\(baseEmail)",
                            password: "StrongP@ssw0rd!"
                        )
                    ))
                )
                #expect(rateLimitResponse.status == .tooManyRequests)
            } catch let error as Abort {
                #expect(error.status == .tooManyRequests)
            }
        }
    }

    @Test("Test rate limit resets after window")
    func testRateLimitTimeReset() async throws {
        try await withTestApp { app in
            let (testEmail, testPassword) = try await setupMockIdentity(app: app)

            // Exhaust rate limit
            for i in 1...7 {
                let response = try await app.test(
                    identity: .authenticate(
                        .credentials(
                            .init(
                                username: testEmail,
                                password: testPassword
                            )
                        )
                    )
                )
                if i < 5 {
                    #expect(response.status == .ok)
                } else if i > 5 {
                    #expect(response.status == .tooManyRequests)
                }
            }

            // Advance time past rate limit window
            @Dependency(\.date) var date
            let currentTime = date()
            let advancedTime = currentTime.addingTimeInterval(61) // Advance >1 minute

            try await withDependencies {
                $0.date = .init { advancedTime }
            } operation: {
                // Request should succeed after window reset
                let response = try await app.test(identity: .authenticate(.credentials(.init(
                    username: testEmail, password: testPassword
                ))))
                #expect(response.status == .ok)
            }
        }
    }
}
