import Testing
import Identity_Shared
import Dependencies
import DependenciesTestSupport
import EmailAddress
import Foundation
import JWT
import ServerFoundation

// MARK: - Access Token Tests

@Suite("Access Token Tests")
struct AccessTokenTests {
    @Test("Access token creation with valid parameters")
    func testAccessTokenCreation() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("test@example.com")
        let signingKey = SigningKey("test-secret-key")

        let token = try Identity.Token.Access(
            identityId: identityId,
            email: email,
            sessionVersion: 1,
            issuer: "test-issuer",
            expiresIn: 900,
            signingKey: signingKey
        )

        #expect(token.identityId == identityId)
        #expect(token.email == email)
        #expect(token.sessionVersion == 1)
    }

    @Test("Access token extracts identity ID from subject")
    func testAccessTokenIdentityIdExtraction() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("user@example.com")
        let signingKey = SigningKey("test-secret")

        let token = try Identity.Token.Access(
            identityId: identityId,
            email: email,
            sessionVersion: 1,
            issuer: "issuer",
            expiresIn: 900,
            signingKey: signingKey
        )

        #expect(token.identityId == identityId)
    }

    @Test("Access token extracts email from subject")
    func testAccessTokenEmailExtraction() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("extract@example.com")
        let signingKey = SigningKey("test-secret")

        let token = try Identity.Token.Access(
            identityId: identityId,
            email: email,
            sessionVersion: 2,
            issuer: "issuer",
            expiresIn: 900,
            signingKey: signingKey
        )

        #expect(token.email == email)
    }

    @Test("Access token validates expiry correctly")
    func testAccessTokenExpiry() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("expiry@example.com")
        let signingKey = SigningKey("test-secret")

        // Create token that expires in 1 second
        let token = try Identity.Token.Access(
            identityId: identityId,
            email: email,
            sessionVersion: 1,
            issuer: "issuer",
            expiresIn: 1,
            signingKey: signingKey
        )

        #expect(!token.isExpired)

        // Wait for expiry
        try await Task.sleep(for: .seconds(2))

        #expect(token.isExpired)
    }

    @Test("Access token should refresh when expiry is near")
    func testAccessTokenShouldRefresh() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("refresh@example.com")
        let signingKey = SigningKey("test-secret")

        // Create token that expires in 4 minutes (less than 5 minute threshold)
        let token = try Identity.Token.Access(
            identityId: identityId,
            email: email,
            sessionVersion: 1,
            issuer: "issuer",
            expiresIn: 240,
            signingKey: signingKey
        )

        #expect(token.shouldRefresh)
    }

    @Test("Access token with additional claims")
    func testAccessTokenWithAdditionalClaims() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("claims@example.com")
        let signingKey = SigningKey("test-secret")

        let token = try Identity.Token.Access(
            identityId: identityId,
            email: email,
            sessionVersion: 1,
            issuer: "issuer",
            expiresIn: 900,
            signingKey: signingKey,
            additionalClaims: ["displayName": "Test User"]
        )

        #expect(token.displayName == "Test User")
    }

    @Test("Access token fails with invalid token type")
    func testAccessTokenInvalidType() async throws {
        let jwt = JWT(
            header: JWT.Header(alg: "HS256"),
            payload: JWT.Payload(
                sub: "\(UUID().uuidString):test@example.com",
                additionalClaims: ["type": "refresh"] // Wrong type
            ),
            signature: Data()
        )

        #expect(throws: Identity.Token.Access.TokenError.invalidTokenType) {
            try Identity.Token.Access(jwt: jwt)
        }
    }
}

// MARK: - Refresh Token Tests

@Suite("Refresh Token Tests")
struct RefreshTokenTests {
    @Test("Refresh token creation with valid parameters")
    func testRefreshTokenCreation() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret-key")

        let token = try withDependencies {
            $0.uuid = .incrementing
        } operation: {
            try Identity.Token.Refresh(
                identityId: identityId,
                sessionVersion: 1,
                issuer: "test-issuer",
                expiresIn: 2592000, // 30 days
                signingKey: signingKey
            )
        }

        #expect(token.identityId == identityId)
        #expect(token.sessionVersion == 1)
        #expect(!token.tokenId.isEmpty)
    }

    @Test("Refresh token extracts identity ID from subject")
    func testRefreshTokenIdentityIdExtraction() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try withDependencies {
            $0.uuid = .incrementing
        } operation: {
            try Identity.Token.Refresh(
                identityId: identityId,
                sessionVersion: 2,
                issuer: "issuer",
                expiresIn: 2592000,
                signingKey: signingKey
            )
        }

        #expect(token.identityId == identityId)
    }

    @Test("Refresh token has unique token ID")
    func testRefreshTokenUniqueId() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try withDependencies {
            $0.uuid = .incrementing
        } operation: {
            try Identity.Token.Refresh(
                identityId: identityId,
                sessionVersion: 1,
                issuer: "issuer",
                expiresIn: 2592000,
                signingKey: signingKey
            )
        }

        #expect(!token.tokenId.isEmpty)
        #expect(UUID(uuidString: token.tokenId) != nil)
    }

    @Test("Refresh token validates expiry correctly")
    func testRefreshTokenExpiry() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try withDependencies {
            $0.uuid = .incrementing
        } operation: {
            try Identity.Token.Refresh(
                identityId: identityId,
                sessionVersion: 1,
                issuer: "issuer",
                expiresIn: 1,
                signingKey: signingKey
            )
        }

        #expect(!token.isExpired)

        try await Task.sleep(for: .seconds(2))

        #expect(token.isExpired)
    }

    @Test("Refresh token fails with invalid token type")
    func testRefreshTokenInvalidType() async throws {
        let jwt = JWT(
            header: JWT.Header(alg: "HS256"),
            payload: JWT.Payload(
                sub: UUID().uuidString,
                jti: UUID().uuidString,
                additionalClaims: ["type": "access"] // Wrong type
            ),
            signature: Data()
        )

        #expect(throws: Identity.Token.Refresh.TokenError.invalidTokenType) {
            try Identity.Token.Refresh(jwt: jwt)
        }
    }

    @Test("Refresh token fails without token ID")
    func testRefreshTokenMissingTokenId() async throws {
        let jwt = JWT(
            header: JWT.Header(alg: "HS256"),
            payload: JWT.Payload(
                sub: UUID().uuidString,
                additionalClaims: ["type": "refresh"]
            ),
            signature: Data()
        )

        #expect(throws: Identity.Token.Refresh.TokenError.missingTokenId) {
            try Identity.Token.Refresh(jwt: jwt)
        }
    }
}

// MARK: - Reauthorization Token Tests

@Suite("Reauthorization Token Tests")
struct ReauthorizationTokenTests {
    @Test("Reauthorization token creation with purpose")
    func testReauthorizationTokenCreation() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try withDependencies {
            $0.uuid = .incrementing
        } operation: {
            try Identity.Token.Reauthorization(
                identityId: identityId,
                sessionVersion: 1,
                purpose: Identity.Token.Reauthorization.Purpose.passwordChange,
                issuer: "issuer",
                expiresIn: 300,
                signingKey: signingKey
            )
        }

        #expect(token.identityId == identityId)
        #expect(token.purpose == Identity.Token.Reauthorization.Purpose.passwordChange)
        #expect(token.sessionVersion == 1)
    }

    @Test("Reauthorization token with allowed operations")
    func testReauthorizationTokenWithOperations() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")
        let operations = ["change_password", "update_email"]

        let token = try withDependencies {
            $0.uuid = .incrementing
        } operation: {
            try Identity.Token.Reauthorization(
                identityId: identityId,
                sessionVersion: 1,
                purpose: "sensitive_ops",
                allowedOperations: operations,
                issuer: "issuer",
                expiresIn: 300,
                signingKey: signingKey
            )
        }

        #expect(token.allowedOperations == operations)
    }

    @Test("Reauthorization token checks allowed operations")
    func testReauthorizationTokenAllowsOperation() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try withDependencies {
            $0.uuid = .incrementing
        } operation: {
            try Identity.Token.Reauthorization(
                identityId: identityId,
                sessionVersion: 1,
                purpose: "test",
                allowedOperations: ["operation_a", "operation_b"],
                issuer: "issuer",
                expiresIn: 300,
                signingKey: signingKey
            )
        }

        #expect(token.allowsOperation("operation_a"))
        #expect(token.allowsOperation("operation_b"))
        #expect(!token.allowsOperation("operation_c"))
    }

    @Test("Reauthorization token with empty operations allows all")
    func testReauthorizationTokenEmptyOperationsAllowsAll() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try withDependencies {
            $0.uuid = .incrementing
        } operation: {
            try Identity.Token.Reauthorization(
                identityId: identityId,
                sessionVersion: 1,
                purpose: "general",
                allowedOperations: [],
                issuer: "issuer",
                expiresIn: 300,
                signingKey: signingKey
            )
        }

        #expect(token.allowsOperation("any_operation"))
    }

    @Test("Reauthorization token validates expiry")
    func testReauthorizationTokenExpiry() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try withDependencies {
            $0.uuid = .incrementing
        } operation: {
            try Identity.Token.Reauthorization(
                identityId: identityId,
                sessionVersion: 1,
                purpose: "test",
                issuer: "issuer",
                expiresIn: 1,
                signingKey: signingKey
            )
        }

        #expect(!token.isExpired)

        try await Task.sleep(for: .seconds(2))

        #expect(token.isExpired)
    }
}

// MARK: - MFA Challenge Token Tests

@Suite("MFA Challenge Token Tests")
struct MFAChallengeTokenTests {
    @Test("MFA challenge token creation")
    func testMFAChallengeTokenCreation() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try Identity.MFA.Challenge.Token(
            identityId: identityId,
            sessionVersion: 1,
            attemptsRemaining: 3,
            issuer: "issuer",
            expiresIn: 300,
            signingKey: signingKey
        )

        #expect(token.identityId == identityId)
        #expect(token.sessionVersion == 1)
        #expect(token.attemptsRemaining == 3)
    }

    @Test("MFA challenge token with available methods")
    func testMFAChallengeTokenWithMethods() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try Identity.MFA.Challenge.Token(
            identityId: identityId,
            sessionVersion: 1,
            attemptsRemaining: 3,
            availableMethods: [.totp],
            issuer: "issuer",
            expiresIn: 300,
            signingKey: signingKey
        )

        #expect(token.availableMethods.contains(.totp))
    }

    @Test("MFA challenge token validates expiry")
    func testMFAChallengeTokenExpiry() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey("test-secret")

        let token = try Identity.MFA.Challenge.Token(
            identityId: identityId,
            sessionVersion: 1,
            issuer: "issuer",
            expiresIn: 1,
            signingKey: signingKey
        )

        #expect(!token.isExpired)

        try await Task.sleep(for: .seconds(2))

        #expect(token.isExpired)
    }

    @Test("MFA challenge token fails with invalid type")
    func testMFAChallengeTokenInvalidType() async throws {
        let jwt = JWT(
            header: JWT.Header(alg: "HS256"),
            payload: JWT.Payload(
                sub: UUID().uuidString,
                additionalClaims: ["type": "access"]
            ),
            signature: Data()
        )

        #expect(throws: Identity.MFA.Challenge.Token.TokenError.invalidTokenType) {
            try Identity.MFA.Challenge.Token(jwt: jwt)
        }
    }
}

// MARK: - MFA TOTP Validation Tests

@Suite("MFA TOTP Validation Tests")
struct TOTPValidationTests {
    @Test("Valid TOTP code format accepted")
    func testValidTOTPCodeFormat() {
        #expect(Identity.MFA.TOTP.isValidCode("123456"))
        #expect(Identity.MFA.TOTP.isValidCode("000000"))
        #expect(Identity.MFA.TOTP.isValidCode("999999"))
        #expect(Identity.MFA.TOTP.isValidCode("12345678")) // 8 digits
    }

    @Test("Invalid TOTP code format rejected")
    func testInvalidTOTPCodeFormat() {
        #expect(!Identity.MFA.TOTP.isValidCode("12345")) // Too short
        #expect(!Identity.MFA.TOTP.isValidCode("123456789")) // Too long
        #expect(!Identity.MFA.TOTP.isValidCode("12345a")) // Contains letter
        #expect(!Identity.MFA.TOTP.isValidCode("123 456")) // Contains space
        #expect(!Identity.MFA.TOTP.isValidCode("")) // Empty
    }

    @Test("Valid Base32 secret accepted")
    func testValidBase32Secret() {
        #expect(Identity.MFA.TOTP.isValidSecret("JBSWY3DPEHPK3PXP"))
        #expect(Identity.MFA.TOTP.isValidSecret("ABCDEFGHIJKLMNOP"))
        #expect(Identity.MFA.TOTP.isValidSecret("2345 6723 ABCD EFGH")) // With spaces - using valid Base32 chars (no 8 or 9)
    }

    @Test("Invalid Base32 secret rejected")
    func testInvalidBase32Secret() {
        #expect(!Identity.MFA.TOTP.isValidSecret("SHORT")) // Too short
        #expect(!Identity.MFA.TOTP.isValidSecret("INVALID@#$%")) // Invalid chars
        #expect(!Identity.MFA.TOTP.isValidSecret("")) // Empty
    }

    @Test("TOTP code sanitization")
    func testTOTPCodeSanitization() {
        #expect(Identity.MFA.TOTP.sanitizeCode("123 456") == "123456")
        #expect(Identity.MFA.TOTP.sanitizeCode("12-34-56") == "123456")
        #expect(Identity.MFA.TOTP.sanitizeCode("12a34b56") == "123456")
    }

    @Test("Base32 secret sanitization")
    func testBase32SecretSanitization() {
        #expect(Identity.MFA.TOTP.sanitizeSecret("ABCD EFGH") == "ABCDEFGH")
        #expect(Identity.MFA.TOTP.sanitizeSecret("abcd-efgh") == "ABCDEFGH")
        #expect(Identity.MFA.TOTP.sanitizeSecret("ABCD@#EFGH") == "ABCDEFGH")
        #expect(Identity.MFA.TOTP.sanitizeSecret("abcd efgh") == "ABCDEFGH")
    }
}

// MARK: - MFA TOTP Utilities Tests

@Suite("MFA TOTP Utilities Tests")
struct TOTPUtilitiesTests {
    @Test("Format manual entry key with spaces")
    func testFormatManualEntryKey() {
        let formatted = Identity.MFA.TOTP.formatManualEntryKey("JBSWY3DPEHPK3PXP")
        #expect(formatted == "JBSW Y3DP EHPK 3PXP")
    }

    @Test("Format manual entry key removes padding")
    func testFormatManualEntryKeyRemovesPadding() {
        let formatted = Identity.MFA.TOTP.formatManualEntryKey("JBSWY3DP====")
        #expect(formatted == "JBSW Y3DP")
    }

    @Test("Format manual entry key with existing spaces")
    func testFormatManualEntryKeyWithSpaces() {
        let formatted = Identity.MFA.TOTP.formatManualEntryKey("JBSW Y3DP EHPK 3PXP")
        #expect(formatted == "JBSW Y3DP EHPK 3PXP")
    }

    @Test("Format manual entry key uppercase conversion")
    func testFormatManualEntryKeyUppercase() {
        let formatted = Identity.MFA.TOTP.formatManualEntryKey("jbswy3dpehpk3pxp")
        #expect(formatted == "JBSW Y3DP EHPK 3PXP")
    }
}

// MARK: - Cookie Tests

@Suite("Cookie Tests")
struct CookieTests {
    @Test("Cookie names are correctly defined")
    func testCookieNames() {
        #expect(Identity.Cookies.Names.accessToken == "access_token")
        #expect(Identity.Cookies.Names.refreshToken == "refresh_token")
        #expect(Identity.Cookies.Names.reauthorizationToken == "reauthorization_token")
        #expect(Identity.Cookies.Names.identityPrefix == "identity.")
    }

    @Test("Cookie expiry times are correctly defined")
    func testCookieExpiry() {
        #expect(Identity.Cookies.Expiry.accessToken == 60 * 15) // 15 minutes
        #expect(Identity.Cookies.Expiry.refreshToken == 60 * 60 * 24 * 30) // 30 days
        #expect(Identity.Cookies.Expiry.reauthorizationToken == 60 * 5) // 5 minutes
        #expect(Identity.Cookies.Expiry.accessTokenDevelopment == 60 * 60) // 1 hour
        #expect(Identity.Cookies.Expiry.refreshTokenDevelopment == 60 * 60 * 24 * 7) // 7 days
    }
}

// MARK: - JWT Extensions Tests

@Suite("JWT Extensions Tests")
struct JWTExtensionsTests {
    @Test("JWT creation with issuer and subject")
    func testJWTCreationWithClaims() throws {
        let key = SigningKey("test-secret")

        let jwt = try JWT.signed(
            algorithm: .hmacSHA256,
            key: key,
            issuer: "test-issuer",
            subject: "test-subject",
            expiresIn: 3600,
            claims: ["custom": "value"]
        )

        #expect(jwt.payload.iss == "test-issuer")
        #expect(jwt.payload.sub == "test-subject")
        #expect(jwt.payload.exp != nil)
        #expect(jwt.payload.iat != nil)
    }

    @Test("JWT creation with custom claims")
    func testJWTCreationWithCustomClaims() throws {
        let key = SigningKey("test-secret")

        let jwt = try JWT.signed(
            algorithm: .hmacSHA256,
            key: key,
            claims: [
                "role": "admin",
                "permissions": ["read", "write"]
            ]
        )

        #expect(jwt.payload.additionalClaim("role", as: String.self) == "admin")
    }

    @Test("JWT creation with token ID")
    func testJWTCreationWithTokenId() throws {
        let key = SigningKey("test-secret")
        let tokenId = UUID().uuidString

        let jwt = try JWT.signed(
            algorithm: .hmacSHA256,
            key: key,
            jti: tokenId
        )

        #expect(jwt.payload.jti == tokenId)
    }

    @Test("JWT expiration calculation")
    func testJWTExpirationCalculation() throws {
        let key = SigningKey("test-secret")
        let expiresIn: TimeInterval = 3600

        let jwt = try JWT.signed(
            algorithm: .hmacSHA256,
            key: key,
            expiresIn: expiresIn
        )

        let exp = try #require(jwt.payload.exp)
        let expectedExp = Date(timeIntervalSinceNow: expiresIn)

        // Allow 1 second tolerance for test execution time
        #expect(abs(exp.timeIntervalSince(expectedExp)) < 1)
    }
}
