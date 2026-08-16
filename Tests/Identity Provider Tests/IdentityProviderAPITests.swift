import Dependencies
import Dependencies_Test_Support
import Foundation
import IdentitiesTypes
import Identity_Provider
import Identity_Shared
import Server_Vapor
import Testing
import Throttling

// MARK: - Test Fixtures

enum TestFixtures {
    static let testEmail = "test@example.com"
    static let testPassword = "TestPassword123!"
    static let testToken = "test-token-12345"
    static let testAPIKey = "api-key-12345"
}

// MARK: - MFA and OAuth Not Implemented Tests

@Suite
struct Test {

    // Note: MFA endpoints require authentication except for .verify
    // .verify uses session tokens and is tested elsewhere in MFA-specific tests

    @Test
    func `OAuth endpoints return not implemented`() async throws {
        try await withDependencies {
            $0[Identity.Provider.Configuration.self] = .testValue
            $0.date = .constant(Date())  // Rate limiter needs date dependency
            // No request needed - OAuth providers is a public endpoint
        } operation: { () async throws in
            let api = Identity.Provider.API.oauth(.providers)

            do {
                _ = try await Identity.Provider.API.response(api: api)
                Issue.record("Expected OAuth to throw not implemented")
            } catch let error as Abort {
                #expect(error.status == .notImplemented)
                #expect(error.reason.contains("OAuth endpoints not yet implemented"))
            }
        }
    }
}

// MARK: - Rate Limiting Tests

@Suite
struct Test {

    // MARK: - Temporarily disabled due to Swift type inference issue with withDependencies
    // See: https://github.com/pointfreeco/swift-dependencies/issues/XXX

    //
    // @Test
    // func `Rate limit exceeded throws too many requests for credentials`() async throws {
    // try await withDependencies {
    // // Create a rate limiter that immediately fails
    // let restrictiveRateLimiter = RateLimiter<String>(
    // windows: [
    // .minutes(1, maxAttempts: 0) // No attempts allowed
    // ]
    // )

    //               // var config = Identity.Provider.Configuration.testValue
    // config.provider.rateLimiters = RateLimiters(
    // credentials: restrictiveRateLimiter
    // )
    // $0[Identity.Provider.Configuration.self] = config
    // } operation: {
    // let credentials = Identity.Authentication.API.Credentials(
    // username: TestFixtures.testEmail,
    // password: TestFixtures.testPassword
    // )
    // let api = Identity.Provider.API.authenticate(.credentials(credentials))

    //               // do {
    // _ = try await Identity.Provider.API.response(api: api)
    // Issue.record("Expected rate limit to be exceeded")
    // } catch let error as Abort {
    // #expect(error.status == .tooManyRequests)
    // }
    // }
    // }

    //       // @Test
    // func `Rate limit exceeded throws too many requests for creation`() async throws {
    // try await withDependencies {
    // let restrictiveRateLimiter = RateLimiter<String>(
    // windows: [
    // .minutes(1, maxAttempts: 0)
    // ]
    // )

    //               // var config = Identity.Provider.Configuration.testValue
    // config.provider.rateLimiters = RateLimiters(
    // credentials: restrictiveRateLimiter
    // )
    // $0[Identity.Provider.Configuration.self] = config
    // } operation: {
    // let request = Identity.Creation.API.Request(
    // email: TestFixtures.testEmail,
    // password: TestFixtures.testPassword
    // )
    // let api = Identity.Provider.API.create(.request(request))

    //               // do {
    // _ = try await Identity.Provider.API.response(api: api)
    // Issue.record("Expected rate limit to be exceeded")
    // } catch let error as Abort {
    // #expect(error.status == .tooManyRequests)
    // }
    // }
    // }

    //       // @Test
    // func `Rate limit allows request within limits`() async throws {
    // try await withDependencies {
    // // Use generous rate limiter
    // let generousRateLimiter = RateLimiter<String>(
    // windows: [
    // .minutes(1, maxAttempts: 100)
    // ]
    // )

    //               // var config = Identity.Provider.Configuration.testValue
    // config.provider.rateLimiters = RateLimiters(
    // credentials: generousRateLimiter
    // )
    // $0[Identity.Provider.Configuration.self] = config
    // } operation: {
    // let credentials = Identity.Authentication.API.Credentials(
    // username: TestFixtures.testEmail,
    // password: TestFixtures.testPassword
    // )
    // let api = Identity.Provider.API.authenticate(.credentials(credentials))

    //               // // Should not throw rate limit error
    // // Will fail with other error (no mocked backend) but that's expected
    // do {
    // _ = try await Identity.Provider.API.response(api: api)
    // } catch let error as Abort {
    // // Should not be rate limit error
    // #expect(error.status != .tooManyRequests)
    // }
    // }
    // }
    //
}

// MARK: - Protection/Authentication Tests

@Suite
struct Test {

    // MARK: - Temporarily disabled due to Swift type inference issue with withDependencies

    //

    //       // @Test
    // func `Delete request with empty token throws unauthorized`() async throws {
    // try await withDependencies {
    // $0[Identity.Provider.Configuration.self] = .testValue
    // } operation: {
    // let request = Identity.Deletion.API.Request(reauthToken: "")
    // let api = Identity.Provider.API.delete(.request(request))

    //               // do {
    // _ = try await Identity.Provider.API.response(api: api)
    // Issue.record("Expected deletion to fail with empty token")
    // } catch let error as Abort {
    // #expect(error.status == .unauthorized)
    // #expect(error.reason == "Invalid token")
    // }
    // }
    // }

    //       // @Test
    // func `Delete endpoints check protection before rate limiting`() async throws {
    // try await withDependencies {
    // // Even with generous rate limits, protection should be checked first
    // let generousRateLimiter = RateLimiter<String>(
    // windows: [
    // .minutes(1, maxAttempts: 100)
    // ]
    // )

    //               // var config = Identity.Provider.Configuration.testValue
    // config.provider.rateLimiters = RateLimiters(
    // tokenAccess: generousRateLimiter
    // )
    // $0[Identity.Provider.Configuration.self] = config
    // } operation: {
    // let request = Identity.Deletion.API.Request(reauthToken: "")
    // let api = Identity.Provider.API.delete(.request(request))

    //               // do {
    // _ = try await Identity.Provider.API.response(api: api)
    // Issue.record("Expected protection check to fail")
    // } catch let error as Abort {
    // // Should fail with unauthorized, not rate limit
    // #expect(error.status == .unauthorized)
    // }
    // }
    // }

    //       // @Test
    // func `Public endpoints don't require request context for protection`() async throws {
    // try await withDependencies {
    // $0[Identity.Provider.Configuration.self] = .testValue
    // // Don't set request - public endpoints shouldn't need it for protection
    // } operation: {
    // let credentials = Identity.Authentication.API.Credentials(
    // username: TestFixtures.testEmail,
    // password: TestFixtures.testPassword
    // )
    // let api = Identity.Provider.API.authenticate(.credentials(credentials))

    //               // // Protection check should pass, will fail in backend call
    // do {
    // _ = try await Identity.Provider.API.response(api: api)
    // } catch {
    // // Should not be unauthorized from protection check
    // if let abort = error as? Abort {
    // #expect(abort.status != .unauthorized || abort.reason != "Unauthenticated.")
    // }
    // }
    // }
    // }
    //
}

// MARK: - Response Handler Tests

@Suite
struct Test {

    // MARK: - Temporarily disabled due to Swift type inference issue with withDependencies

    //

    //       // @Test
    // func `Response handler calls rate limiter before protection`() async throws {
    // try await withDependencies {
    // // Restrictive rate limiter should fail before protection check
    // let restrictiveRateLimiter = RateLimiter<String>(
    // windows: [
    // .minutes(1, maxAttempts: 0)
    // ]
    // )

    //               // var config = Identity.Provider.Configuration.testValue
    // config.provider.rateLimiters = RateLimiters(
    // credentials: restrictiveRateLimiter
    // )
    // $0[Identity.Provider.Configuration.self] = config
    // } operation: {
    // let credentials = Identity.Authentication.API.Credentials(
    // username: TestFixtures.testEmail,
    // password: TestFixtures.testPassword
    // )
    // let api = Identity.Provider.API.authenticate(.credentials(credentials))

    //               // do {
    // _ = try await Identity.Provider.API.response(api: api)
    // Issue.record("Expected rate limit to fail")
    // } catch let error as Abort {
    // #expect(error.status == .tooManyRequests)
    // }
    // }
    // }
    //

}

// MARK: - Configuration Tests

@Suite(

    .dependencies {
        $0.date = .constant(Date())
    }
)
struct Test {

    @Test
    func `Test configuration has valid default values`() throws {
        let config = Identity.Provider.Configuration.testValue

        #expect(config.provider.baseURL.absoluteString == "/")
        #expect(config.provider.domain == nil)
        #expect(config.provider.issuer == nil)
        #expect(config.provider.tokens.accessToken.expires == 900)  // 15 minutes
        #expect(config.provider.tokens.refreshToken.expires == 2_592_000)  // 30 days
        #expect(config.provider.tokens.reauthorizationToken.expires == 300)  // 5 minutes
    }

    @Test
    func `Test configuration has working rate limiters`() async throws {
        let config = Identity.Provider.Configuration.testValue

        // Rate limiters should be initialized and usable
        let credentialsLimit = await config.provider.rateLimiters.credentials.checkLimit("test-key")
        #expect(credentialsLimit.isAllowed == true)

        let tokenLimit = await config.provider.rateLimiters.tokenAccess.checkLimit("test-token")
        #expect(tokenLimit.isAllowed == true)
    }

    @Test
    func `Custom rate limiters can be configured`() async throws {
        let customLimiter = RateLimiter<String>(
            windows: [
                .minutes(1, maxAttempts: 5)
            ]
        )

        var config = Identity.Provider.Configuration.testValue
        config.provider.rateLimiters = RateLimiters(credentials: customLimiter)

        let limit = await config.provider.rateLimiters.credentials.checkLimit("test")
        #expect(limit.isAllowed == true)

        // After 5 attempts, should be blocked
        for _ in 0..<5 {
            await config.provider.rateLimiters.credentials.recordAttempt("test")
            await config.provider.rateLimiters.credentials.recordFailure("test")
        }

        let limitAfter = await config.provider.rateLimiters.credentials.checkLimit("test")
        #expect(limitAfter.isAllowed == false)
    }
}

// MARK: - API Type Tests

@Suite
struct Test {

    @Test
    func `Authentication credentials can be created`() {
        let credentials: Identity.Authentication.Credentials = .init(
            username: TestFixtures.testEmail,
            password: TestFixtures.testPassword
        )

        #expect(credentials.username == TestFixtures.testEmail)
        #expect(credentials.password == TestFixtures.testPassword)
    }

    @Test
    func `Creation request can be created`() {
        let request: Identity.Creation.Request = .init(
            email: TestFixtures.testEmail,
            password: TestFixtures.testPassword
        )

        #expect(request.email == TestFixtures.testEmail)
        #expect(request.password == TestFixtures.testPassword)
    }

    @Test
    func `Deletion request can be created`() {
        let request: Identity.Deletion.Request = .init(reauthToken: TestFixtures.testToken)
        #expect(request.reauthToken == TestFixtures.testToken)
    }

    @Test
    func `Password reset request can be created`() {
        let request: Identity.Password.Reset.Request = .init(email: TestFixtures.testEmail)
        #expect(request.email == TestFixtures.testEmail)
    }

    @Test
    func `Email change request can be created`() {
        let request: Identity.Email.Change.Request = .init(newEmail: "new@example.com")
        #expect(request.newEmail == "new@example.com")
    }
}
