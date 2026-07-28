import Dependencies
import Dependencies_Test_Support
import EmailAddress
import Foundation
import Identity_Shared
import JWT
import Server
import Testing

// MARK: - Access Token Tests

@Suite
struct `Access Token Tests` {
    @Test
    func `Access token creation with valid parameters`() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("test@example.com")
        let signingKey = SigningKey.symmetric(string: "test-secret-key")

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

    @Test
    func `Access token extracts identity ID from subject`() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("user@example.com")
        let signingKey = SigningKey.symmetric(string: "test-secret")

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

    @Test
    func `Access token extracts email from subject`() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("extract@example.com")
        let signingKey = SigningKey.symmetric(string: "test-secret")

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

    @Test
    func `Access token validates expiry correctly`() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("expiry@example.com")
        let signingKey = SigningKey.symmetric(string: "test-secret")

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

    @Test
    func `Access token should refresh when expiry is near`() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("refresh@example.com")
        let signingKey = SigningKey.symmetric(string: "test-secret")

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

    @Test
    func `Access token with additional claims`() async throws {
        let identityId = Identity.ID(UUID())
        let email = try EmailAddress("claims@example.com")
        let signingKey = SigningKey.symmetric(string: "test-secret")

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

    @Test
    func `Access token fails with invalid token type`() async throws {
        let jwt = JWT(
            header: JWT.Header(alg: "HS256"),
            payload: JWT.Payload(
                sub: "\(UUID().uuidString):test@example.com",
                additionalClaims: ["type": "refresh"]  // Wrong type
            ),
            signature: Data()
        )

        #expect(throws: Identity.Token.Access.TokenError.invalidTokenType) {
            try Identity.Token.Access(jwt: jwt)
        }
    }
}

// MARK: - Refresh Token Tests

@Suite
struct `Refresh Token Tests` {
    @Test
    func `Refresh token creation with valid parameters`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret-key")

        let token = try withDependencies {
            $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
        } operation: {
            try Identity.Token.Refresh(
                identityId: identityId,
                sessionVersion: 1,
                issuer: "test-issuer",
                expiresIn: 2_592_000,  // 30 days
                signingKey: signingKey
            )
        }

        #expect(token.identityId == identityId)
        #expect(token.sessionVersion == 1)
        #expect(!token.tokenId.isEmpty)
    }

    @Test
    func `Refresh token extracts identity ID from subject`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

        let token = try withDependencies {
            $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
        } operation: {
            try Identity.Token.Refresh(
                identityId: identityId,
                sessionVersion: 2,
                issuer: "issuer",
                expiresIn: 2_592_000,
                signingKey: signingKey
            )
        }

        #expect(token.identityId == identityId)
    }

    @Test
    func `Refresh token has unique token ID`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

        let token = try withDependencies {
            $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
        } operation: {
            try Identity.Token.Refresh(
                identityId: identityId,
                sessionVersion: 1,
                issuer: "issuer",
                expiresIn: 2_592_000,
                signingKey: signingKey
            )
        }

        #expect(!token.tokenId.isEmpty)
        #expect(UUID(uuidString: token.tokenId) != nil)
    }

    @Test
    func `Refresh token validates expiry correctly`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

        let token = try withDependencies {
            $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
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

    @Test
    func `Refresh token fails with invalid token type`() async throws {
        let jwt = JWT(
            header: JWT.Header(alg: "HS256"),
            payload: JWT.Payload(
                sub: UUID().uuidString,
                jti: UUID().uuidString,
                additionalClaims: ["type": "access"]  // Wrong type
            ),
            signature: Data()
        )

        #expect(throws: Identity.Token.Refresh.TokenError.invalidTokenType) {
            try Identity.Token.Refresh(jwt: jwt)
        }
    }

    @Test
    func `Refresh token fails without token ID`() async throws {
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

@Suite
struct `Reauthorization Token Tests` {
    @Test
    func `Reauthorization token creation with purpose`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

        let token = try withDependencies {
            $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
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

    @Test
    func `Reauthorization token with allowed operations`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")
        let operations = ["change_password", "update_email"]

        let token = try withDependencies {
            $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
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

    @Test
    func `Reauthorization token checks allowed operations`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

        let token = try withDependencies {
            $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
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

    @Test
    func `Reauthorization token with empty operations allows all`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

        let token = try withDependencies {
            $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
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

    @Test
    func `Reauthorization token validates expiry`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

        let token = try withDependencies {
            $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
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

@Suite
struct `MFA Challenge Token Tests` {
    @Test
    func `MFA challenge token creation`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

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

    @Test
    func `MFA challenge token with available methods`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

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

    @Test
    func `MFA challenge token validates expiry`() async throws {
        let identityId = Identity.ID(UUID())
        let signingKey = SigningKey.symmetric(string: "test-secret")

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

    @Test
    func `MFA challenge token fails with invalid type`() async throws {
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

@Suite
struct `MFA TOTP Validation Tests` {
    @Test
    func `Valid TOTP code format accepted`() {
        #expect(Identity.MFA.TOTP.isValidCode("123456"))
        #expect(Identity.MFA.TOTP.isValidCode("000000"))
        #expect(Identity.MFA.TOTP.isValidCode("999999"))
        #expect(Identity.MFA.TOTP.isValidCode("12345678"))  // 8 digits
    }

    @Test
    func `Invalid TOTP code format rejected`() {
        #expect(!Identity.MFA.TOTP.isValidCode("12345"))  // Too short
        #expect(!Identity.MFA.TOTP.isValidCode("123456789"))  // Too long
        #expect(!Identity.MFA.TOTP.isValidCode("12345a"))  // Contains letter
        #expect(!Identity.MFA.TOTP.isValidCode("123 456"))  // Contains space
        #expect(!Identity.MFA.TOTP.isValidCode(""))  // Empty
    }

    @Test
    func `Valid Base32 secret accepted`() {
        #expect(Identity.MFA.TOTP.isValidSecret("JBSWY3DPEHPK3PXP"))
        #expect(Identity.MFA.TOTP.isValidSecret("ABCDEFGHIJKLMNOP"))
        #expect(Identity.MFA.TOTP.isValidSecret("2345 6723 ABCD EFGH"))  // With spaces - using valid Base32 chars (no 8 or 9)
    }

    @Test
    func `Invalid Base32 secret rejected`() {
        #expect(!Identity.MFA.TOTP.isValidSecret("SHORT"))  // Too short
        #expect(!Identity.MFA.TOTP.isValidSecret("INVALID@#$%"))  // Invalid chars
        #expect(!Identity.MFA.TOTP.isValidSecret(""))  // Empty
    }

    @Test
    func `TOTP code sanitization`() {
        #expect(Identity.MFA.TOTP.sanitizeCode("123 456") == "123456")
        #expect(Identity.MFA.TOTP.sanitizeCode("12-34-56") == "123456")
        #expect(Identity.MFA.TOTP.sanitizeCode("12a34b56") == "123456")
    }

    @Test
    func `Base32 secret sanitization`() {
        #expect(Identity.MFA.TOTP.sanitizeSecret("ABCD EFGH") == "ABCDEFGH")
        #expect(Identity.MFA.TOTP.sanitizeSecret("abcd-efgh") == "ABCDEFGH")
        #expect(Identity.MFA.TOTP.sanitizeSecret("ABCD@#EFGH") == "ABCDEFGH")
        #expect(Identity.MFA.TOTP.sanitizeSecret("abcd efgh") == "ABCDEFGH")
    }
}

// MARK: - MFA TOTP Utilities Tests

@Suite
struct `MFA TOTP Utilities Tests` {
    @Test
    func `Format manual entry key with spaces`() {
        let formatted = Identity.MFA.TOTP.formatManualEntryKey("JBSWY3DPEHPK3PXP")
        #expect(formatted == "JBSW Y3DP EHPK 3PXP")
    }

    @Test
    func `Format manual entry key removes padding`() {
        let formatted = Identity.MFA.TOTP.formatManualEntryKey("JBSWY3DP====")
        #expect(formatted == "JBSW Y3DP")
    }

    @Test
    func `Format manual entry key with existing spaces`() {
        let formatted = Identity.MFA.TOTP.formatManualEntryKey("JBSW Y3DP EHPK 3PXP")
        #expect(formatted == "JBSW Y3DP EHPK 3PXP")
    }

    @Test
    func `Format manual entry key uppercase conversion`() {
        let formatted = Identity.MFA.TOTP.formatManualEntryKey("jbswy3dpehpk3pxp")
        #expect(formatted == "JBSW Y3DP EHPK 3PXP")
    }
}

// MARK: - Cookie Tests

@Suite
struct `Cookie Tests` {
    @Test
    func `Cookie names are correctly defined`() {
        #expect(Identity.Cookies.Names.accessToken == "access_token")
        #expect(Identity.Cookies.Names.refreshToken == "refresh_token")
        #expect(Identity.Cookies.Names.reauthorizationToken == "reauthorization_token")
        #expect(Identity.Cookies.Names.identityPrefix == "identity.")
    }

    @Test
    func `Cookie expiry times are correctly defined`() {
        #expect(Identity.Cookies.Expiry.accessToken == 60 * 15)  // 15 minutes
        #expect(Identity.Cookies.Expiry.refreshToken == 60 * 60 * 24 * 30)  // 30 days
        #expect(Identity.Cookies.Expiry.reauthorizationToken == 60 * 5)  // 5 minutes
        #expect(Identity.Cookies.Expiry.accessTokenDevelopment == 60 * 60)  // 1 hour
        #expect(Identity.Cookies.Expiry.refreshTokenDevelopment == 60 * 60 * 24 * 7)  // 7 days
    }
}

// MARK: - JWT Extensions Tests

@Suite
struct `JWT Extensions Tests` {
    @Test
    func `JWT creation with issuer and subject`() throws {
        let key = SigningKey.symmetric(string: "test-secret")

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

    @Test
    func `JWT creation with custom claims`() throws {
        let key = SigningKey.symmetric(string: "test-secret")

        let jwt = try JWT.signed(
            algorithm: .hmacSHA256,
            key: key,
            claims: [
                "role": "admin",
                "permissions": ["read", "write"],
            ]
        )

        #expect(jwt.payload.additionalClaim("role", as: String.self) == "admin")
    }

    @Test
    func `JWT creation with token ID`() throws {
        let key = SigningKey.symmetric(string: "test-secret")
        let tokenId = UUID().uuidString

        let jwt = try JWT.signed(
            algorithm: .hmacSHA256,
            key: key,
            jti: tokenId
        )

        #expect(jwt.payload.jti == tokenId)
    }

    @Test
    func `JWT expiration calculation`() throws {
        let key = SigningKey.symmetric(string: "test-secret")
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
