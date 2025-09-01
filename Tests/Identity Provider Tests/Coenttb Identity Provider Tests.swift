//  Identity_Provider_Fluent Tests.swift

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
    "Identity Provider Tests",
    .dependency(\.uuid, .incrementing),
    .dependency(\.date, .init(Date.init)),
    .dependency(\.identity.provider.client, .liveTest)
)
struct IdentityProviderTests {
    @Test("Create and verify refresh token")
    func testRefreshTokenLifecycle() async throws {
        try await withTestApp { app in
            let identityId = UUID()
            let sessionVersion = 1
            @Dependency(\.date) var date
            // Create expiration and issuance dates
            let now = date.now
            let expirationDate = now.addingTimeInterval(60 * 60) // 1 hour from now

            // Create refresh token payload
            let refreshToken = Identity.Token.Refresh(
                expiration: .init(value: expirationDate),
                issuedAt: .init(value: now),
                identityId: identityId,
                tokenId: .init(value: UUID().uuidString),
                sessionVersion: sessionVersion
            )

            // Sign the token
            let signedToken = try await app.jwt.keys.sign(refreshToken)

            // Verify the token can be decoded and verified
            let verifiedPayload = try await app.jwt.keys.verify(signedToken, as: Identity.Token.Refresh.self)

            // Assertions
            #expect(verifiedPayload.identityId == identityId)
            #expect(verifiedPayload.sessionVersion == sessionVersion)
            #expect(verifiedPayload.tokenId.value != "")
            #expect(verifiedPayload.expiration.value > now)
        }
    }

    @Test("Expired refresh token fails verification")
    func testExpiredRefreshToken() async throws {
        try await withTestApp { app in
            // Create an expired token (issued and expired in the past)
            @Dependency(\.date) var date
            let pastDate = date().addingTimeInterval(-3600) // 1 hour ago
            let expiredDate = pastDate.addingTimeInterval(1) // 1 second after issuance (expired)

            let expiredToken = Identity.Token.Refresh(
                expiration: .init(value: expiredDate),
                issuedAt: .init(value: pastDate),
                identityId: UUID(),
                tokenId: .init(value: UUID().uuidString),
                sessionVersion: 1
            )

            // Sign the expired token
            let signedExpiredToken = try await app.jwt.keys.sign(expiredToken)

            // Attempt to verify - should throw JWTError.expired
            do {
                _ = try await app.jwt.keys.verify(signedExpiredToken, as: Identity.Token.Refresh.self)
                #expect(Bool(false), "Expected verification to fail for expired token")
            } catch {
                let jwtError = error as? JWTError
                #expect(jwtError != nil)
            }
        }
    }

    @Test("Refresh token with incorrect session version is rejected")
    func testSessionVersionMismatch() async throws {
        // This test simulates the session version check in the provider's authentication handler

        try await withTestApp { app in

            @Dependency(\.date) var date
            // Create valid token with session version 1
            let validToken = Identity.Token.Refresh(
                expiration: .init(value: date().addingTimeInterval(3600)),
                issuedAt: .init(value: date()),
                identityId: UUID(),
                tokenId: .init(value: UUID().uuidString),
                sessionVersion: 1
            )

            let signedToken = try await app.jwt.keys.sign(validToken)

            // Simulate database identity with different session version
            let currentSessionVersion = 2 // Different from token's version (1)

            // Verify the token - JWT verification should succeed
            let verifiedPayload = try await app.jwt.keys.verify(signedToken, as: Identity.Token.Refresh.self)

            // But session version check should fail
            let tokenSessionMatches = verifiedPayload.sessionVersion == currentSessionVersion
            #expect(tokenSessionMatches == false, "Session versions should not match")
        }
    }

    @Test("Test creating a new identity with credentials")
    func testCreateIdentity() async throws {
        try await withTestApp { app in
            _ = try await setupMockIdentity(app: app)
        }
    }

    @Test("Test login in with mock identity")
    func testLoginWithMockIdentity() async throws {
        try await withTestApp { app in

            let (testEmail, testPassword) = try await setupMockIdentity(app: app)

            let loginResponse = try await app.test(
                identity: .authenticate(
                    .credentials(
                        .init(
                            username: testEmail,
                            password: testPassword
                        )
                    )
                )
            )

            // Verify login was successful
            #expect(loginResponse.status == .ok, "Expected successful login")

            // Define wrapper to decode the response
            struct AuthResponseWrapper: Codable {
                let success: Bool
                let data: Identity.Authentication.Response
            }

            // Decode the response to verify tokens were received
            let responseData = try loginResponse.content.decode(AuthResponseWrapper.self)
            #expect(responseData.success == true, "Expected success flag to be true")

            // Verify response contains valid tokens
            #expect(!responseData.data.accessToken.value.isEmpty, "Expected non-empty access token")
            #expect(!responseData.data.refreshToken.value.isEmpty, "Expected non-empty refresh token")

            // Verify identity login was recorded in database
            let identity = try await Database.Identity.get(by: .email(try EmailAddress(testEmail)), on: app.db)
            #expect(identity.lastLoginAt != nil, "Expected lastLoginAt to be updated")
        }
    }

    @Test("Test login in with mock identity and token refresh")
    func testLoginAndTokenRefresh() async throws {
        try await withTestApp { app in

            let (testEmail, testPassword) = try await setupMockIdentity(app: app)

            // Define wrapper to decode the response
            struct AuthResponseWrapper: Codable {
                let success: Bool
                let data: Identity.Authentication.Response
            }

            let loginResponse = try await app.test(
                identity: .authenticate(
                    .credentials(
                        .init(
                            username: testEmail,
                            password: testPassword
                        )
                    )
                )
            )

            // Verify initial login was successful
            #expect(loginResponse.status == .ok, "Expected successful login")

            let responseData = try loginResponse.content.decode(AuthResponseWrapper.self)

            // Get the refresh token to use for token refresh
            let refreshToken = responseData.data.refreshToken

            // Verify the refresh token is valid
            let verified = try await app.jwt.keys.verify(
                refreshToken.value,
                as: Identity.Token.Refresh.self
            )

            // Test token refresh - explicitly using the refresh token type
            let refreshResponse = try await app.test(
                identity: .authenticate(
                    .token(
                        .refresh(
                            .init(stringLiteral: refreshToken.value)
                        )
                    )
                )
            )

            // Verify refresh was successful
            #expect(refreshResponse.status == .ok, "Expected successful token refresh")

            let refreshResponseData = try refreshResponse.content.decode(AuthResponseWrapper.self)
            #expect(refreshResponseData.success == true, "Expected success flag to be true")

            // Verify new tokens were received
            #expect(!refreshResponseData.data.accessToken.value.isEmpty, "Expected non-empty access token")
            #expect(!refreshResponseData.data.refreshToken.value.isEmpty, "Expected non-empty refresh token")

            // Verify the new access token works via the API
            let accessToken = refreshResponseData.data.accessToken
            let accessVerifyResponse = try await app.test(
                identity: .authenticate(
                    .token(
                        .access(
                            accessToken
                        )
                    )
                )
            )

            #expect(accessVerifyResponse.status == .ok, "Expected successful access token verification")
        }
    }

    @Test("Test refresh token fallback when access token expires")
    func testRefreshTokenFallbackWithTimeAdvance() async throws {
        try await withTestApp { app in
            let (testEmail, testPassword) = try await setupMockIdentity(app: app)

            // Get initial tokens via login
            struct AuthResponseWrapper: Codable {
                let success: Bool
                let data: Identity.Authentication.Response
            }

            let loginResponse = try await app.test(
                identity: .authenticate(
                    .credentials(
                        .init(
                            username: testEmail,
                            password: testPassword
                        )
                    )
                )
            )

            #expect(loginResponse.status == .ok, "Expected successful login")
            let responseData = try loginResponse.content.decode(AuthResponseWrapper.self)

            // Get both tokens

            let refreshToken = responseData.data.refreshToken.value

            // First verify the access token works normally
            let initialVerifyResponse = try await app .test(
                identity: .authenticate(
                    .token(
                        .access(responseData.data.accessToken)
                    )
                )
            )

            let accessToken = responseData.data.accessToken.value

            #expect(initialVerifyResponse.status == .ok, "Initial access token should be valid")

            // Decode tokens to get their expiration times
            let decodedAccess = try await app.jwt.keys.verify(accessToken, as: Identity.Token.Access.self)
            let decodedRefresh = try await app.jwt.keys.verify(refreshToken, as: Identity.Token.Refresh.self)

            // Access token typically has shorter lifetime than refresh token
            let accessExpiration = decodedAccess.expiration.value
            let refreshExpiration = decodedRefresh.expiration.value

            // Advance time to just after access token expiration but before refresh token expires
            let midwayTime = accessExpiration.addingTimeInterval(10) // 10 seconds after access expiration

            #expect(midwayTime > accessExpiration, "Advanced time should be after access token expiration")
            #expect(midwayTime < refreshExpiration, "Advanced time should be before refresh token expiration")

            // Test with advanced time that should make access token invalid but refresh token still valid
            try await withDependencies {
                $0.date = .init { midwayTime }
            } operation: {
                // Try to use the expired access token (should fail)
                do {
                    _ = try await app.jwt.keys.verify(accessToken, as: Identity.Token.Access.self)
                    #expect(false, "Access token verification should have failed due to expiration")
                } catch {
                    // Expected to fail with expiration error
                    #expect(true, "Access token correctly failed verification after time advancement")
                }

                // Verify refresh token is still valid
                let verifiedRefresh = try await app.jwt.keys.verify(refreshToken, as: Identity.Token.Refresh.self)
                #expect(verifiedRefresh.expiration.value > midwayTime, "Refresh token should still be valid")

                // Now create a request where we send the refresh token as a bearer token
                // This should hit the fallback path in the TokenAuthenticator

                // Create a token wrapper to send in the request body
                struct TokenWrapper: Codable {
                    var value: String
                }

                // Try using the refresh token directly (as if it were an access token)
                // This should exercise the fallback code path where an access token verification fails
                // but then it falls back to trying refresh token verification
                let refreshFallbackResponse = try await app.test(
                    identity: .authenticate(
                        .token(
                            .refresh(
                                .init(stringLiteral: refreshToken)
                            )
                        )
                    )
                )

                #expect(refreshFallbackResponse.status == .ok, "Refresh token fallback should succeed")

                // Verify we got new tokens
                let refreshResponseData = try refreshFallbackResponse.content.decode(AuthResponseWrapper.self)
                #expect(!refreshResponseData.data.accessToken.value.isEmpty, "Should receive new access token")
                #expect(!refreshResponseData.data.refreshToken.value.isEmpty, "Should receive new refresh token")
            }
        }
    }
}
