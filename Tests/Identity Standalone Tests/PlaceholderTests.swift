import Dependencies
import Dependencies_Test_Support
import EmailAddress
import Foundation
import IdentitiesTypes
import Identity_Backend
import Identity_Frontend
import Identity_Shared
import Identity_Standalone
import JWT
import Records
import RecordsTestSupport
import Testing
import Throttling
import URLRouting
import Vapor

// MARK: - Test Fixtures

enum TestFixtures {
    /// Default test email
    static let testEmail = EmailAddress(rawValue: "test@example.com")!

    /// Default test password
    static let testPassword = "SecurePassword123!"

    /// Generate unique email for test isolation
    static func uniqueEmail(prefix: String = "test") -> EmailAddress {
        let uuid = UUID().uuidString.prefix(8)
        return EmailAddress(rawValue: "\(prefix)!-\(uuid)@example.com")
    }

    /// Creates a test identity in the database
    static func createTestIdentity(
        email: EmailAddress = testEmail,
        password: String = testPassword,
        verified: Bool = true,
        db: any Database.Connection.`Protocol`
    ) async throws -> Identity.Record {
        let passwordHash = try Bcrypt.hash(password)

        return try await Identity.Record
            .insert {
                Identity.Record.Draft(
                    email: email,
                    passwordHash: passwordHash,
                    emailVerificationStatus: verified ? .verified : .pending,
                    sessionVersion: 1
                )
            }
            .returning(\.self)
            .fetchOne(db)!
    }

    /// Creates a test identity with unique email for test isolation
    static func createUniqueTestIdentity(
        emailPrefix: String = "test",
        password: String = testPassword,
        verified: Bool = true,
        db: any Database.Connection.`Protocol`
    ) async throws -> Identity.Record {
        try await createTestIdentity(
            email: uniqueEmail(prefix: emailPrefix),
            password: password,
            verified: verified,
            db: db
        )
    }
}

// MARK: - Configuration Tests

@Suite
struct Test {

    @Test
    func `Standalone configuration initializes with required fields`() throws {
        let baseURL = try #require(URL(string: "https://example.com"))
        let router = Identity.Route.Router().baseURL(baseURL.absoluteString)
        let jwt = Identity.Token.Client.test

        let config = Identity.Standalone.Configuration(
            baseURL: baseURL,
            router: router,
            jwt: jwt
        )

        #expect(config.baseURL == baseURL)
        // Email configuration exists
        _ = config.email.sendVerificationEmail
    }

    @Test
    func `Standalone configuration uses default cookies when not provided`() throws {
        let baseURL = try #require(URL(string: "https://example.com"))
        let router = Identity.Route.Router().baseURL(baseURL.absoluteString)
        let jwt = Identity.Token.Client.test

        let config = Identity.Standalone.Configuration(
            baseURL: baseURL,
            router: router,
            jwt: jwt
        )

        // Should use production-style cookies by default
        #expect(config.cookies.accessToken.isHTTPOnly == true)
        #expect(config.cookies.refreshToken.isHTTPOnly == true)
    }

    @Test
    func `Standalone configuration includes rate limiters by default`() throws {
        let baseURL = try #require(URL(string: "https://example.com"))
        let router = Identity.Route.Router().baseURL(baseURL.absoluteString)
        let jwt = Identity.Token.Client.test

        let config = Identity.Standalone.Configuration(
            baseURL: baseURL,
            router: router,
            jwt: jwt
        )

        #expect(config.rateLimiters != nil)
        #expect(config.rateLimiters?.credentials != nil)
    }

    @Test
    func `Standalone configuration accepts MFA configuration`() throws {
        let baseURL = try #require(URL(string: "https://example.com"))
        let router = Identity.Route.Router().baseURL(baseURL.absoluteString)
        let jwt = Identity.Token.Client.test

        let totpConfig = try Identity.MFA.TOTP.Configuration(
            issuer: "TestApp",
            algorithm: .sha1,
            digits: 6
        )

        let backupCodesConfig = Identity.MFA.BackupCodes.Configuration(
            codeLength: 10
        )

        let mfaConfig = Identity.MFA.Configuration(
            totp: totpConfig,
            backupCodes: backupCodesConfig
        )

        let config = Identity.Standalone.Configuration(
            baseURL: baseURL,
            router: router,
            jwt: jwt,
            mfa: mfaConfig
        )

        #expect(config.mfa != nil)
        #expect(config.mfa?.totp?.issuer == "TestApp")
    }
}

// MARK: - Cookie Configuration Tests

@Suite
struct Test {

    @Test
    func `Production cookies require HTTPS`() throws {
        let baseURL = try #require(URL(string: "https://example.com"))
        let router = Identity.Route.Router().baseURL(baseURL.absoluteString)

        let cookies = Identity.Frontend.Configuration.Cookies.production(
            domain: "example.com",
            router: router
        )

        #expect(cookies.accessToken.isSecure == true)
        #expect(cookies.refreshToken.isSecure == true)
        #expect(cookies.reauthorizationToken.isSecure == true)
    }

    @Test
    func `Production cookies use strict same-site policy`() throws {
        let baseURL = try #require(URL(string: "https://example.com"))
        let router = Identity.Route.Router().baseURL(baseURL.absoluteString)

        let cookies = Identity.Frontend.Configuration.Cookies.production(
            domain: "example.com",
            router: router
        )

        #expect(cookies.accessToken.sameSitePolicy == .strict)
        #expect(cookies.refreshToken.sameSitePolicy == .strict)
    }

    @Test
    func `Development cookies allow HTTP`() throws {
        let cookies = Identity.Frontend.Configuration.Cookies.development()

        #expect(cookies.accessToken.isSecure == false)
        #expect(cookies.refreshToken.isSecure == false)
    }

    @Test
    func `Development cookies use lax same-site policy`() throws {
        let cookies = Identity.Frontend.Configuration.Cookies.development()

        #expect(cookies.accessToken.sameSitePolicy == .lax)
        #expect(cookies.refreshToken.sameSitePolicy == .lax)
    }

    @Test
    func `Refresh token has restricted path in production`() throws {
        let baseURL = try #require(URL(string: "https://example.com"))
        let router = Identity.Route.Router().baseURL(baseURL.absoluteString)

        let cookies = Identity.Frontend.Configuration.Cookies.production(
            domain: "example.com",
            router: router
        )

        // Refresh token should have restricted path
        #expect(cookies.refreshToken.path != "/")
    }
}

// MARK: - Token Client Tests

@Suite(

    .dependencies {
        $0.uuid = .incrementing
    }
)
struct Test {

    @Test
    func `Token client generates valid access token`() async throws {
        let identityId = Identity.ID(UUID())
        let email = TestFixtures.testEmail
        let sessionVersion = 1

        let tokenClient = Identity.Token.Client.test

        let tokenString = try await tokenClient.generateAccess(
            identityId,
            email,
            sessionVersion
        )

        #expect(!tokenString.isEmpty)

        // Verify the token can be parsed
        let verifiedToken = try await tokenClient.verifyAccess(tokenString)
        #expect(verifiedToken.identityId == identityId)
        #expect(verifiedToken.email == email)
    }

    @Test
    func `Token client generates valid refresh token`() async throws {
        let identityId = Identity.ID(UUID())
        let sessionVersion = 1

        let tokenClient = Identity.Token.Client.test

        let tokenString = try await tokenClient.generateRefresh(
            identityId,
            sessionVersion
        )

        #expect(!tokenString.isEmpty)

        // Verify the token can be parsed
        let verifiedToken = try await tokenClient.verifyRefresh(tokenString)
        #expect(verifiedToken.identityId == identityId)
    }

    @Test
    func `Token client generates token pair`() async throws {
        let identityId = Identity.ID(UUID())
        let email = TestFixtures.testEmail
        let sessionVersion = 1

        let tokenClient = Identity.Token.Client.test

        let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
            identityId,
            email,
            sessionVersion
        )

        #expect(!accessToken.isEmpty)
        #expect(!refreshToken.isEmpty)

        // Verify both tokens
        let verifiedAccess = try await tokenClient.verifyAccess(accessToken)
        let verifiedRefresh = try await tokenClient.verifyRefresh(refreshToken)

        #expect(verifiedAccess.identityId == identityId)
        #expect(verifiedRefresh.identityId == identityId)
    }

    @Test
    func `Token client refreshes access token`() async throws {
        let identityId = Identity.ID(UUID())
        let email = TestFixtures.testEmail
        let sessionVersion = 1

        let tokenClient = Identity.Token.Client.test

        let refreshToken = try await tokenClient.generateRefresh(
            identityId,
            sessionVersion
        )

        let newAccessToken = try await tokenClient.refreshAccess(
            refreshToken,
            identityId,
            email,
            sessionVersion
        )

        #expect(!newAccessToken.isEmpty)

        // Verify new access token
        let verifiedToken = try await tokenClient.verifyAccess(newAccessToken)
        #expect(verifiedToken.identityId == identityId)
    }

    @Test
    func `Token client identifies token types correctly`() async throws {
        let identityId = Identity.ID(UUID())
        let email = TestFixtures.testEmail
        let sessionVersion = 1

        let tokenClient = Identity.Token.Client.test

        let accessToken = try await tokenClient.generateAccess(
            identityId,
            email,
            sessionVersion
        )

        let refreshToken = try await tokenClient.generateRefresh(
            identityId,
            sessionVersion
        )

        let accessType = try await tokenClient.identifyTokenType(accessToken)
        let refreshType = try await tokenClient.identifyTokenType(refreshToken)

        #expect(accessType == .access)
        #expect(refreshType == .refresh)
    }

    @Test
    func `Token client detects non-expired tokens`() async throws {
        let tokenClient = Identity.Token.Client.test
        let identityId = Identity.ID(UUID())
        let email = TestFixtures.testEmail
        let sessionVersion = 1

        // Generate token (test tokens should not be immediately expired)
        let tokenString = try await tokenClient.generateAccess(
            identityId,
            email,
            sessionVersion
        )

        // Token should not be expired immediately
        let isExpired = try await tokenClient.isExpired(tokenString)
        #expect(isExpired == false)
    }
}

// MARK: - Authenticator Middleware Tests

@Suite
struct Test {

    @Test
    func `Unified authenticator initializes`() throws {
        // This test verifies the authenticator structure exists and can be initialized
        let authenticator = Identity.Standalone.Authenticator()

        // Verify it's not nil (basic existence test)
        #expect(String(describing: authenticator).contains("Authenticator"))
    }

    @Test
    func `Unified authenticator has default configuration`() throws {
        let config = Identity.Standalone.Authenticator.Configuration.default

        #expect(config.enableCookies == true)
        #expect(config.enableBearerTokens == true)
    }

    @Test
    func `Unified authenticator has API-only configuration`() throws {
        let config = Identity.Standalone.Authenticator.Configuration.apiOnly

        #expect(config.enableCookies == false)
        #expect(config.enableBearerTokens == true)
    }

    @Test
    func `Unified authenticator has web-only configuration`() throws {
        let config = Identity.Standalone.Authenticator.Configuration.webOnly

        #expect(config.enableCookies == true)
        #expect(config.enableBearerTokens == false)
    }

    @Test
    func `Token authenticator initializes`() throws {
        let authenticator = Identity.Standalone.TokenAuthenticator()

        #expect(String(describing: authenticator).contains("TokenAuthenticator"))
    }

    @Test
    func `Cookie authenticator initializes`() throws {
        let authenticator = Identity.Standalone.CookieAuthenticator()

        #expect(String(describing: authenticator).contains("CookieAuthenticator"))
    }

    @Test
    func `Credentials authenticator initializes`() throws {
        let authenticator = Identity.Standalone.CredentialsAuthenticator()

        #expect(String(describing: authenticator).contains("CredentialsAuthenticator"))
    }
}

// MARK: - Rate Limiter Tests

@Suite
struct Test {

    @Test
    func `Default rate limiters include credentials limiter`() throws {
        let limiters = RateLimiters.default

        // Verify credentials limiter exists (it's not optional)
        _ = limiters.credentials
    }

    @Test
    func `Standalone has all rate limiters configured`() throws {
        let limiters = RateLimiters.default

        // Standalone has all limiters (they're not optional)
        _ = limiters.credentials
        _ = limiters.tokenAccess
        _ = limiters.tokenRefresh
    }
}

// MARK: - Integration Tests

@Suite(

    .dependencies {
        $0.uuid = .incrementing
    }
)
struct Test {

    @Test
    func `Token generation and verification flow`() async throws {
        let identityId = Identity.ID(UUID())
        let testEmail = TestFixtures.testEmail
        let sessionVersion = 1

        // Generate tokens
        let tokenClient = Identity.Token.Client.test
        let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
            identityId,
            testEmail,
            sessionVersion
        )

        // Verify tokens work
        let verifiedAccess = try await tokenClient.verifyAccess(accessToken)
        let verifiedRefresh = try await tokenClient.verifyRefresh(refreshToken)

        #expect(verifiedAccess.identityId == identityId)
        #expect(verifiedRefresh.identityId == identityId)
    }

    @Test
    func `Token refresh with mismatched session version fails`() async throws {
        let identityId = Identity.ID(UUID())
        let testEmail = TestFixtures.testEmail
        let oldSessionVersion = 1
        let newSessionVersion = 2

        let tokenClient = Identity.Token.Client.test

        // Generate refresh token with old session version
        let refreshToken = try await tokenClient.generateRefresh(
            identityId,
            oldSessionVersion
        )

        // Try to refresh with mismatched session version - should fail
        await #expect(throws: Error.self) {
            try await tokenClient.refreshAccess(
                refreshToken,
                identityId,
                testEmail,
                newSessionVersion
            )
        }
    }

    @Test
    func `Configuration provides all required components`() throws {
        let baseURL = try #require(URL(string: "https://example.com"))
        let router = Identity.Route.Router().baseURL(baseURL.absoluteString)
        let jwt = Identity.Token.Client.test

        let standaloneConfig = Identity.Standalone.Configuration(
            baseURL: baseURL,
            router: router,
            jwt: jwt
        )

        // Verify all components are present
        #expect(standaloneConfig.baseURL == baseURL)
        #expect(standaloneConfig.cookies.accessToken.isHTTPOnly == true)
        _ = standaloneConfig.email.sendVerificationEmail  // Email config exists
        #expect(standaloneConfig.rateLimiters != nil)
    }

    @Test
    func `Standalone API router initializes`() throws {
        let router = Identity.Standalone.API.Router()

        // Verify router exists and can be created
        #expect(String(describing: router).contains("Router"))
    }
}
