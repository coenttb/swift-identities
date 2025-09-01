////  Identity_Consumer_Tests.swift
//
// import Identity_Consumer
// import Identity_Shared
// // import DependenciesTestSupport
// import Foundation
// import JWT
// import Testing
// import Vapor
// import VaporTesting
// import EmailAddress
//
//// Mock client implementation for testing
// extension Identity.Consumer.Client {
//    static let liveTest: Self = .live()
// }
//
// @Suite(
//    "Identity Consumer Tests",
//    .dependency(\.uuid, .incrementing),
//    .dependency(\.date, .init(Date.init)),
//    .dependency(\.identity.consumer.client, .liveTest)
// )
// struct IdentityConsumerTests {
//
//    // Test authentication success flow
//    @Test("Test authentication with credentials")
//    func testAuthentication() async throws {
//        try await withTestConsumerApp { app in
//            // Setup test request
//            let testCredentials = Identity.Authentication.Credentials(
//                username: "test@example.com",
//                password: "securePassword123!"
//            )
//            
//            let authResponse = try await app.test(
//                identity: .authenticate(
//                    .credentials(testCredentials)
//                )
//            )
//            
//            // Verify login was successful
//            #expect(authResponse.status == .ok, "Expected successful login")
//            
//            // Define wrapper to decode the response
//            struct AuthResponseWrapper: Codable {
//                let success: Bool
//                let data: Identity.Authentication.Response
//            }
//            
//            // Decode the response to verify tokens were received
//            let responseData = try authResponse.content.decode(AuthResponseWrapper.self)
//            #expect(responseData.success == true, "Expected success flag to be true")
//            
//            // Verify response contains valid tokens
//            #expect(!responseData.data.accessToken.value.isEmpty, "Expected non-empty access token")
//            #expect(!responseData.data.refreshToken.value.isEmpty, "Expected non-empty refresh token")
//        }
//    }
//    
//    // Test token refresh flow
//    @Test("Test token refresh flow")
//    func testTokenRefresh() async throws {
//        try await withTestConsumerApp { app in
//            // Start with a mock refresh token
//            let mockRefreshToken = "mock-refresh-token"
//            
//            // Test the refresh endpoint
//            let refreshResponse = try await app.test(
//                identity: .authenticate(
//                    .token(
//                        .refresh(
//                            .init(stringLiteral: mockRefreshToken)
//                        )
//                    )
//                )
//            )
//            
//            // Verify refresh was successful
//            #expect(refreshResponse.status == .ok, "Expected successful token refresh")
//            
//            // Define wrapper to decode the response
//            struct AuthResponseWrapper: Codable {
//                let success: Bool
//                let data: Identity.Authentication.Response
//            }
//            
//            // Decode the response and check for new tokens
//            let responseData = try refreshResponse.content.decode(AuthResponseWrapper.self)
//            #expect(responseData.success == true, "Expected success flag to be true")
//            
//            // Verify we got new tokens
//            #expect(!responseData.data.accessToken.value.isEmpty, "Expected new access token")
//            #expect(!responseData.data.refreshToken.value.isEmpty, "Expected new refresh token")
//            #expect(responseData.data.accessToken.value == "new-mock-access-token", "Expected specific test access token")
//            #expect(responseData.data.refreshToken.value == "new-mock-refresh-token", "Expected specific test refresh token")
//        }
//    }
//    
//    // Test account creation
//    @Test("Test account creation")
//    func testAccountCreation() async throws {
//        try await withTestConsumerApp { app in
//            // Setup creation request
//            let createRequest = Identity.Creation.Request(
//                email: "new-user@example.com",
//                password: "securePassword123!"
//            )
//            
//            let createResponse = try await app.test(
//                identity: .create(
//                    .request(createRequest)
//                )
//            )
//            
//            // Verify creation was successful
//            #expect(createResponse.status == .ok, "Expected successful account creation")
//            
//            // Define wrapper to decode the response
//            struct CreateResponseWrapper: Codable {
//                let success: Bool
//            }
//            
//            // Decode response and verify
//            let responseData = try createResponse.content.decode(CreateResponseWrapper.self)
//            #expect(responseData.success == true, "Expected success flag to be true")
//        }
//    }
//    
//    // Test email verification
//    @Test("Test email verification")
//    func testEmailVerification() async throws {
//        try await withTestConsumerApp { app in
//            // Setup verification request
//            let verifyRequest = Identity.Creation.Verification(
//                token: "mock-verification-token",
//                email: "user@example.com"
//            )
//            
//            let verifyResponse = try await app.test(
//                identity: .create(
//                    .verify(verifyRequest)
//                )
//            )
//            
//            // Verify verification was successful
//            #expect(verifyResponse.status == .ok, "Expected successful verification")
//            
//            // Define wrapper to decode the response
//            struct VerificationResponseWrapper: Codable {
//                let success: Bool
//            }
//            
//            // Decode response and verify
//            let responseData = try verifyResponse.content.decode(VerificationResponseWrapper.self)
//            #expect(responseData.success == true, "Expected success flag to be true")
//        }
//    }
//    
//    // Test password reset flow
//    @Test("Test password reset flow")
//    func testPasswordReset() async throws {
//        try await withTestConsumerApp { app in
//            // Setup password reset request
//            let resetRequest = Identity.Password.Reset.Request(
//                email: "user@example.com"
//            )
//            
//            let resetResponse = try await app.test(
//                identity: .password(
//                    .reset(
//                        .request(resetRequest)
//                    )
//                )
//            )
//            
//            // Verify reset initiation was successful
//            #expect(resetResponse.status == .ok, "Expected successful password reset initiation")
//            
//            // Define wrapper to decode the response
//            struct ResetResponseWrapper: Codable {
//                let success: Bool
//            }
//            
//            // Decode response and verify
//            let responseData = try resetResponse.content.decode(ResetResponseWrapper.self)
//            #expect(responseData.success == true, "Expected success flag to be true")
//            
//            // Now test reset confirmation
//            let resetConfirmRequest = Identity.Password.Reset.Confirm(
//                token: "mock-reset-token",
//                newPassword: "newSecurePassword123!"
//            )
//            
//            let resetConfirmResponse = try await app.test(
//                identity: .password(
//                    .reset(
//                        .confirm(resetConfirmRequest)
//                    )
//                )
//            )
//            
//            // Verify reset confirmation was successful
//            #expect(resetConfirmResponse.status == .ok, "Expected successful password reset confirmation")
//            
//            // Define wrapper to decode the response
//            struct ResetConfirmResponseWrapper: Codable {
//                let success: Bool
//            }
//            
//            // Decode response and verify
//            let confirmResponseData = try resetConfirmResponse.content.decode(ResetConfirmResponseWrapper.self)
//            #expect(confirmResponseData.success == true, "Expected success flag to be true")
//        }
//    }
//    
//    // Test email change flow
//    @Test("Test email change flow")
//    func testEmailChange() async throws {
//        try await withTestConsumerApp { app in
//            // Setup mock access token for authentication
//            let mockAccessToken = "mock-access-token"
//            
//            // Setup test request with email change
//            let emailChangeRequest = Identity.Email.Change.Request(
//                newEmail: "new-email@example.com"
//            )
//            
//            // Add authorization header with access token
//            let emailChangeResponse = try await app.test { req in
//                try req.init(identity: .email(.change(.request(emailChangeRequest))))
//                req.headers.bearerAuthorization = BearerAuthorization(token: mockAccessToken)
//            }
//            
//            // Verify email change was successful
//            #expect(emailChangeResponse.status == .ok, "Expected successful email change request")
//            
//            // Define wrapper to decode the response
//            struct EmailChangeResponseWrapper: Codable {
//                let success: Bool
//                let data: Identity.Email.ChangeResponse
//            }
//            
//            // Decode response and verify
//            let responseData = try emailChangeResponse.content.decode(EmailChangeResponseWrapper.self)
//            #expect(responseData.success == true, "Expected success flag to be true")
//            
//            // Now test email change confirmation
//            let confirmRequest = Identity.Email.ConfirmRequest(
//                token: "mock-change-token",
//                email: "new-email@example.com"
//            )
//            
//            let confirmResponse = try await app.test(
//                identity: .email(
//                    .change(
//                        .confirm(confirmRequest)
//                    )
//                )
//            )
//            
//            // Verify confirmation was successful
//            #expect(confirmResponse.status == .ok, "Expected successful email change confirmation")
//            
//            // Define wrapper to decode the response
//            struct ConfirmResponseWrapper: Codable {
//                let success: Bool
//                let data: Identity.Email.ConfirmResponse
//            }
//            
//            // Decode confirm response and verify
//            let confirmResponseData = try confirmResponse.content.decode(ConfirmResponseWrapper.self)
//            #expect(confirmResponseData.success == true, "Expected success flag to be true")
//        }
//    }
//    
//    // Test view rendering
//    @Test("Test login view rendering")
//    func testLoginViewRendering() async throws {
//        try await withTestConsumerApp { app in
//            // Request the login view
//            let viewResponse = try await app.test(
//                identity: .view(.authenticate(.login))
//            )
//            
//            // Verify view rendering was successful
//            #expect(viewResponse.status == .ok, "Expected successful view rendering")
//            #expect(viewResponse.headers.contentType?.subType == "html", "Expected HTML content")
//            
//            // Check if the response body contains key HTML elements
//            let bodyString = viewResponse.body.string
//            #expect(bodyString.contains("<form"), "Expected form in HTML output")
//            #expect(bodyString.contains("login-form-id"), "Expected form ID in HTML output")
//            #expect(bodyString.contains("email"), "Expected email field in form")
//            #expect(bodyString.contains("password"), "Expected password field in form")
//        }
//    }
//    
//    // Test account creation view
//    @Test("Test account creation view rendering")
//    func testCreateAccountViewRendering() async throws {
//        try await withTestConsumerApp { app in
//            // Request the account creation view
//            let viewResponse = try await app.test(
//                identity: .view(.create(.account))
//            )
//            
//            // Verify view rendering was successful
//            #expect(viewResponse.status == .ok, "Expected successful view rendering")
//            #expect(viewResponse.headers.contentType?.subType == "html", "Expected HTML content")
//            
//            // Check if the response body contains key HTML elements
//            let bodyString = viewResponse.body.string
//            #expect(bodyString.contains("<form"), "Expected form in HTML output")
//            #expect(bodyString.contains("email"), "Expected email field in form")
//            #expect(bodyString.contains("password"), "Expected password field in form")
//        }
//    }
//    
//    // Test cookie management
//    @Test("Test cookies are set correctly after authentication")
//    func testCookieManagement() async throws {
//        try await withTestConsumerApp { app in
//            // Setup test credentials
//            let testCredentials = Identity.Authentication.Credentials(
//                username: "test@example.com",
//                password: "securePassword123!"
//            )
//            
//            // Test authentication with cookie response
//            let authResponse = try await app.test(
//                identity: .authenticate(
//                    .credentials(testCredentials)
//                )
//            )
//            
//            // Verify login was successful
//            #expect(authResponse.status == .ok, "Expected successful login")
//            
//            // Check cookies in the response
//            let cookies = authResponse.headers[.setCookie]
//            #expect(!cookies.isEmpty, "Expected cookies to be set in response")
//            
//            // Check for specific cookies
//            let accessTokenCookie = cookies.first { $0.contains("access_token=") }
//            let refreshTokenCookie = cookies.first { $0.contains("refresh_token=") }
//            
//            #expect(accessTokenCookie != nil, "Expected access token cookie to be set")
//            #expect(refreshTokenCookie != nil, "Expected refresh token cookie to be set")
//            
//            // Verify secure and httpOnly flags are set
//            if let accessTokenCookie = accessTokenCookie {
//                #expect(accessTokenCookie.contains("HttpOnly"), "Expected HttpOnly flag on access token cookie")
//                #expect(accessTokenCookie.contains("Secure"), "Expected Secure flag on access token cookie")
//            }
//            
//            if let refreshTokenCookie = refreshTokenCookie {
//                #expect(refreshTokenCookie.contains("HttpOnly"), "Expected HttpOnly flag on refresh token cookie")
//                #expect(refreshTokenCookie.contains("Secure"), "Expected Secure flag on refresh token cookie")
//            }
//        }
//    }
//    
//    // Test logout functionality
//    @Test("Test logout functionality and cookie clearing")
//    func testLogout() async throws {
//        try await withTestConsumerApp { app in
//            // Test logout endpoint
//            let logoutResponse = try await app.test(
//                identity: .authenticate(.logout)
//            )
//            
//            // Verify logout was successful
//            #expect(logoutResponse.status == .ok, "Expected successful logout")
//            
//            // Check for cookie expiration in response
//            let cookies = logoutResponse.headers[.setCookie]
//            #expect(!cookies.isEmpty, "Expected cookies to be cleared in response")
//            
//            // Check specific cookies are being expired
//            let accessTokenCookie = cookies.first { $0.contains("access_token=") }
//            let refreshTokenCookie = cookies.first { $0.contains("refresh_token=") }
//            
//            #expect(accessTokenCookie != nil, "Expected access token cookie to be cleared")
//            #expect(refreshTokenCookie != nil, "Expected refresh token cookie to be cleared")
//            
//            // Verify expiration is set
//            if let accessTokenCookie = accessTokenCookie {
//                #expect(accessTokenCookie.contains("Max-Age=0") || accessTokenCookie.contains("Expires="), 
//                       "Expected expiration on access token cookie")
//            }
//            
//            if let refreshTokenCookie = refreshTokenCookie {
//                #expect(refreshTokenCookie.contains("Max-Age=0") || refreshTokenCookie.contains("Expires="), 
//                       "Expected expiration on refresh token cookie")
//            }
//        }
//    }
//    
//    // Test protected route access
//    @Test("Test protected route access with valid token")
//    func testProtectedRouteAccess() async throws {
//        try await withTestConsumerApp { app in
//            // Setup mock access token
//            let mockAccessToken = "mock-access-token"
//            
//            // Test a protected endpoint
//            let protectedResponse = try await app.test { req in
//                try req.init(identity: .email(.change(.request(.init(newEmail: "new@example.com")))))
//                req.headers.bearerAuthorization = BearerAuthorization(token: mockAccessToken)
//            }
//            
//            // Verify access was granted
//            #expect(protectedResponse.status == .ok, "Expected successful access to protected route")
//        }
//    }
//    
//    // Test protected route rejection
//    @Test("Test protected route rejection with invalid token")
//    func testProtectedRouteRejection() async throws {
//        try await withTestConsumerApp { app in
//            // Use an invalid token
//            let invalidToken = "invalid-token"
//            
//            // Configure client to reject this specific token
//            try await withDependencies {
//                $0.identity.consumer.client.authenticate.token.access = { token in
//                    if token == invalidToken {
//                        throw Identity.Client.Authenticate.Error.unauthorizedAccess
//                    }
//                    return Identity.Token.Access(
//                        expiration: .init(value: Date().addingTimeInterval(3600)),
//                        issuedAt: .init(value: Date()),
//                        identityId: UUID(),
//                        tokenId: .init(value: UUID().uuidString),
//                        email: "test@example.com"
//                    )
//                }
//            } operation: {
//                // Test a protected endpoint with invalid token
//                let protectedResponse = try await app.test { req in
//                    try req.init(identity: .email(.change(.request(.init(newEmail: "new@example.com")))))
//                    req.headers.bearerAuthorization = BearerAuthorization(token: invalidToken)
//                }
//                
//                // Verify access was denied
//                #expect(protectedResponse.status == .unauthorized, "Expected unauthorized response for invalid token")
//            }
//        }
//    }
//    
//    // Test reauthorization workflow
//    @Test("Test reauthorization workflow for sensitive operations")
//    func testReauthorizationFlow() async throws {
//        try await withTestConsumerApp { app in
//            // Setup mock access token
//            let mockAccessToken = "mock-access-token"
//            
//            // Request the reauthorization view first
//            let reauthorizationViewResponse = try await app.test { req in
//                try req.init(identity: .view(.reauthorization(.request)))
//                req.headers.bearerAuthorization = BearerAuthorization(token: mockAccessToken)
//            }
//            
//            // Verify view rendering
//            #expect(reauthorizationViewResponse.status == .ok, "Expected successful reauthorization view")
//            #expect(reauthorizationViewResponse.headers.contentType?.subType == "html", "Expected HTML content")
//            
//            // Now submit reauthorization request
//            let reauthorizationRequest = Identity.Reauthorization.Request(password: "securePassword123!")
//            
//            let reauthorizationResponse = try await app.test { req in
//                try req.init(identity: .authenticate(.reauthorize(reauthorizationRequest)))
//                req.headers.bearerAuthorization = BearerAuthorization(token: mockAccessToken)
//            }
//            
//            // Verify reauthorization success
//            #expect(reauthorizationResponse.status == .ok, "Expected successful reauthorization")
//            
//            // Define wrapper to decode the response
//            struct ReauthResponseWrapper: Codable {
//                let success: Bool
//                let data: JWT.Token
//            }
//            
//            // Decode response and check for reauthorization token
//            let responseData = try reauthorizationResponse.content.decode(ReauthResponseWrapper.self)
//            #expect(responseData.success == true, "Expected success flag to be true")
//            #expect(!responseData.data.reauthorizationToken.value.isEmpty, "Expected reauthorization token")
//            
//            // Check cookies in the response
//            let cookies = reauthorizationResponse.headers[.setCookie]
//            let reauthorizationCookie = cookies.first { $0.contains("reauthorization_token=") }
//            #expect(reauthorizationCookie != nil, "Expected reauthorization token cookie to be set")
//        }
//    }
// }
//
//// Helper extension for test app
// extension TestingHTTPRequest {
//    init(identity route: Identity.API) throws {
//        @Dependency(\.identity.consumer.router) var router
//        
//        let urlRequestData = try router.print(route)
//        try self.init(urlRequestData)
//    }
// }
//
// extension Application {
//    func test(identity route: Identity.API) async throws -> TestingHTTPResponse {
//        try await self.testing().performTest(request: .init(identity: route))
//    }
// }
