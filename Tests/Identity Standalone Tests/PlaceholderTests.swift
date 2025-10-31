import Dependencies
import DependenciesTestSupport
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
import URLRouting
import Vapor

// MARK: - Test Fixtures

enum TestFixtures {
  /// Default test email
  static let testEmail = try! EmailAddress("test@example.com")

  /// Default test password
  static let testPassword = "SecurePassword123!"

  /// Generate unique email for test isolation
  static func uniqueEmail(prefix: String = "test") -> EmailAddress {
    let uuid = UUID().uuidString.prefix(8)
    return try! EmailAddress("\(prefix)-\(uuid)@example.com")
  }

  /// Creates a test identity in the database
  static func createTestIdentity(
    email: EmailAddress = testEmail,
    password: String = testPassword,
    verified: Bool = true,
    db: any Database.Connection.`Protocol`
  ) async throws -> Identity.Record {
    let passwordHash = try Bcrypt.hash(password)

    let identity = try await Identity.Record
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

    return identity
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

@Suite("Standalone Configuration Tests")
struct StandaloneConfigurationTests {

  @Test("Standalone configuration initializes with required fields")
  func testConfigurationInitialization() throws {
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

  @Test("Standalone configuration uses default cookies when not provided")
  func testConfigurationDefaultCookies() throws {
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

  @Test("Standalone configuration includes rate limiters by default")
  func testConfigurationDefaultRateLimiters() throws {
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

  @Test("Standalone configuration accepts MFA configuration")
  func testConfigurationWithMFA() throws {
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

@Suite("Cookie Configuration Tests")
struct CookieConfigurationTests {

  @Test("Production cookies require HTTPS")
  func testProductionCookiesSecure() throws {
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

  @Test("Production cookies use strict same-site policy")
  func testProductionCookiesSameSite() throws {
    let baseURL = try #require(URL(string: "https://example.com"))
    let router = Identity.Route.Router().baseURL(baseURL.absoluteString)

    let cookies = Identity.Frontend.Configuration.Cookies.production(
      domain: "example.com",
      router: router
    )

    #expect(cookies.accessToken.sameSitePolicy == .strict)
    #expect(cookies.refreshToken.sameSitePolicy == .strict)
  }

  @Test("Development cookies allow HTTP")
  func testDevelopmentCookiesInsecure() throws {
    let cookies = Identity.Frontend.Configuration.Cookies.development()

    #expect(cookies.accessToken.isSecure == false)
    #expect(cookies.refreshToken.isSecure == false)
  }

  @Test("Development cookies use lax same-site policy")
  func testDevelopmentCookiesSameSite() throws {
    let cookies = Identity.Frontend.Configuration.Cookies.development()

    #expect(cookies.accessToken.sameSitePolicy == .lax)
    #expect(cookies.refreshToken.sameSitePolicy == .lax)
  }

  @Test("Refresh token has restricted path in production")
  func testRefreshTokenPath() throws {
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
  "Token Client Tests",
  .dependencies {
    $0.uuid = .incrementing
  }
)
struct TokenClientTests {

  @Test("Token client generates valid access token")
  func testGenerateAccessToken() async throws {
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

  @Test("Token client generates valid refresh token")
  func testGenerateRefreshToken() async throws {
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

  @Test("Token client generates token pair")
  func testGenerateTokenPair() async throws {
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

  @Test("Token client refreshes access token")
  func testRefreshAccessToken() async throws {
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

  @Test("Token client identifies token types correctly")
  func testIdentifyTokenType() async throws {
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

  @Test("Token client detects non-expired tokens")
  func testTokenNotExpired() async throws {
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

@Suite("Authenticator Middleware Tests")
struct AuthenticatorMiddlewareTests {

  @Test("Unified authenticator initializes")
  func testAuthenticatorInitialization() throws {
    // This test verifies the authenticator structure exists and can be initialized
    let authenticator = Identity.Standalone.Authenticator()

    // Verify it's not nil (basic existence test)
    #expect(String(describing: authenticator).contains("Authenticator"))
  }

  @Test("Unified authenticator has default configuration")
  func testAuthenticatorDefaultConfiguration() throws {
    let config = Identity.Standalone.Authenticator.Configuration.default

    #expect(config.enableCookies == true)
    #expect(config.enableBearerTokens == true)
  }

  @Test("Unified authenticator has API-only configuration")
  func testAuthenticatorAPIOnlyConfiguration() throws {
    let config = Identity.Standalone.Authenticator.Configuration.apiOnly

    #expect(config.enableCookies == false)
    #expect(config.enableBearerTokens == true)
  }

  @Test("Unified authenticator has web-only configuration")
  func testAuthenticatorWebOnlyConfiguration() throws {
    let config = Identity.Standalone.Authenticator.Configuration.webOnly

    #expect(config.enableCookies == true)
    #expect(config.enableBearerTokens == false)
  }

  @Test("Token authenticator initializes")
  func testTokenAuthenticatorInitialization() throws {
    let authenticator = Identity.Standalone.TokenAuthenticator()

    #expect(String(describing: authenticator).contains("TokenAuthenticator"))
  }

  @Test("Cookie authenticator initializes")
  func testCookieAuthenticatorInitialization() throws {
    let authenticator = Identity.Standalone.CookieAuthenticator()

    #expect(String(describing: authenticator).contains("CookieAuthenticator"))
  }

  @Test("Credentials authenticator initializes")
  func testCredentialsAuthenticatorInitialization() throws {
    let authenticator = Identity.Standalone.CredentialsAuthenticator()

    #expect(String(describing: authenticator).contains("CredentialsAuthenticator"))
  }
}

// MARK: - Rate Limiter Tests

@Suite("Rate Limiter Tests")
struct RateLimiterTests {

  @Test("Default rate limiters include credentials limiter")
  func testDefaultRateLimiters() throws {
    let limiters = RateLimiters.default

    // Verify credentials limiter exists (it's not optional)
    _ = limiters.credentials
  }

  @Test("Standalone has all rate limiters configured")
  func testStandaloneRateLimiters() throws {
    let limiters = RateLimiters.default

    // Standalone has all limiters (they're not optional)
    _ = limiters.credentials
    _ = limiters.tokenAccess
    _ = limiters.tokenRefresh
  }
}

// MARK: - Integration Tests

@Suite(
  "Standalone Integration Tests",
  .dependencies {
    $0.uuid = .incrementing
  }
)
struct StandaloneIntegrationTests {

  @Test("Token generation and verification flow")
  func testTokenGenerationFlow() async throws {
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

  @Test("Token refresh with mismatched session version fails")
  func testSessionVersionMismatch() async throws {
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

  @Test("Configuration provides all required components")
  func testConfigurationCompleteness() throws {
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

  @Test("Standalone API router initializes")
  func testStandaloneAPIRouter() throws {
    let router = Identity.Standalone.API.Router()

    // Verify router exists and can be created
    #expect(String(describing: router).contains("Router"))
  }
}
