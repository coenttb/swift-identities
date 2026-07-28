import EmailAddress
import Foundation
import Identity_Shared
import JWT
import RFC_7519
import Server
import Testing

@Suite
struct `Token Signing Tests` {

    private static let secret = "a-signing-secret-long-enough-for-hmac-sha-256"
    private static let otherSecret = "a-different-secret-of-comparable-length-xxx"

    private static var signingKey: SigningKey { .symmetric(string: secret) }
    private static var verificationKey: VerificationKey { .symmetric(string: secret) }

    private static func accessToken(
        identityId: Identity.ID = Identity.ID(UUID()),
        sessionVersion: Int = 1,
        key: SigningKey = signingKey
    ) throws -> Identity.Token.Access {
        try Identity.Token.Access(
            identityId: identityId,
            email: try EmailAddress("holder@example.com"),
            sessionVersion: sessionVersion,
            issuer: "test-issuer",
            expiresIn: 900,
            signingKey: key
        )
    }

    @Test
    func `Accepts a token signed with the verification key`() throws {
        let token = try Self.accessToken()
        #expect(try token.verify(with: Self.verificationKey))
    }

    @Test
    func `Rejects a signature that does not match`() throws {
        let token = try Self.accessToken(key: .symmetric(string: Self.otherSecret))
        #expect(try token.verify(with: Self.verificationKey) == false)
    }

    @Test
    func `Rejects a token whose signature has been replaced`() throws {
        let token = try Self.accessToken()
        let stripped = try Identity.Token.Access(
            jwt: JWT(
                header: token.jwt.header,
                payload: token.jwt.payload,
                signature: Data()
            )
        )

        #expect(try stripped.verify(with: Self.verificationKey) == false)
    }

    @Test
    func `Rejects a payload altered after signing`() throws {
        let token = try Self.accessToken(sessionVersion: 1)

        let escalated = try Identity.Token.Access(
            jwt: JWT(
                header: token.jwt.header,
                payload: JWT.Payload(
                    iss: token.jwt.payload.iss,
                    sub: "\(UUID().uuidString):attacker@example.com",
                    aud: token.jwt.payload.aud,
                    exp: token.jwt.payload.exp,
                    nbf: token.jwt.payload.nbf,
                    iat: token.jwt.payload.iat,
                    jti: token.jwt.payload.jti,
                    additionalClaims: ["sev": 99, "type": "access"]
                ),
                signature: token.jwt.signature
            )
        )

        #expect(try escalated.verify(with: Self.verificationKey) == false)
    }

    @Test
    func `Rejects an expiry extended after signing`() throws {
        let token = try Self.accessToken()

        let extended = try Identity.Token.Access(
            jwt: JWT(
                header: token.jwt.header,
                payload: JWT.Payload(
                    iss: token.jwt.payload.iss,
                    sub: token.jwt.payload.sub,
                    aud: token.jwt.payload.aud,
                    exp: Date(timeIntervalSinceNow: 60 * 60 * 24 * 365),
                    nbf: token.jwt.payload.nbf,
                    iat: token.jwt.payload.iat,
                    jti: token.jwt.payload.jti,
                    additionalClaims: ["sev": 1, "type": "access"]
                ),
                signature: token.jwt.signature
            )
        )

        #expect(try extended.verify(with: Self.verificationKey) == false)
    }

    @Test
    func `Rejects a token declaring an unexpected algorithm`() throws {
        let token = try Self.accessToken()

        let relabelled = try Identity.Token.Access(
            jwt: JWT(
                header: JWT.Header(
                    alg: "none",
                    typ: token.jwt.header.typ,
                    cty: nil,
                    kid: nil,
                    additionalParameters: nil
                ),
                payload: token.jwt.payload,
                signature: Data()
            )
        )

        #expect(throws: RFC_7519.Error.self) {
            try relabelled.verify(with: Self.verificationKey)
        }
    }

    @Test
    func `Issues tokens under the pinned algorithm`() throws {
        let token = try Self.accessToken()
        #expect(token.jwt.header.alg == Identity.Token.Signing.algorithm.algorithmName)
        #expect(token.jwt.header.alg == "HS256")
        #expect(!token.jwt.signature.isEmpty)
    }

    @Test
    func `Produces a different signature for a different subject`() throws {
        let first = try Self.accessToken(identityId: Identity.ID(UUID()))
        let second = try Self.accessToken(identityId: Identity.ID(UUID()))

        #expect(first.jwt.signature != second.jwt.signature)
    }

    @Test
    func `Rejects a refresh token signed with another key`() throws {
        let token = try Identity.Token.Refresh(
            identityId: Identity.ID(UUID()),
            sessionVersion: 1,
            issuer: "test-issuer",
            expiresIn: 3600,
            signingKey: .symmetric(string: Self.otherSecret)
        )

        #expect(try token.verify(with: Self.verificationKey) == false)
    }

    @Test
    func `Rejects a reauthorization token signed with another key`() throws {
        let token = try Identity.Token.Reauthorization(
            identityId: Identity.ID(UUID()),
            sessionVersion: 1,
            purpose: Identity.Token.Reauthorization.Purpose.general,
            issuer: "test-issuer",
            signingKey: .symmetric(string: Self.otherSecret)
        )

        #expect(try token.verify(with: Self.verificationKey) == false)
    }

    @Test
    func `Rejects an MFA challenge token signed with another key`() throws {
        let token = try Identity.MFA.Challenge.Token(
            identityId: Identity.ID(UUID()),
            sessionVersion: 1,
            issuer: "test-issuer",
            signingKey: .symmetric(string: Self.otherSecret)
        )

        #expect(try token.verify(with: Self.verificationKey) == false)
    }

    @Test
    func `Rejects a token presented to the token client under another key`() async throws {
        let client = Identity.Token.Client.live(
            configuration: .init(
                issuer: "test-issuer",
                secretKey: Self.secret
            )
        )

        let issuedElsewhere = try Identity.Token.Access(
            identityId: Identity.ID(UUID()),
            email: try EmailAddress("attacker@example.com"),
            sessionVersion: 1,
            issuer: "test-issuer",
            expiresIn: 900,
            signingKey: .symmetric(string: Self.otherSecret)
        )

        await #expect(throws: (any Swift.Error).self) {
            try await client.verifyAccess(try issuedElsewhere.token)
        }
    }

    @Test
    func `Accepts a token the token client issued itself`() async throws {
        let client = Identity.Token.Client.live(
            configuration: .init(
                issuer: "test-issuer",
                secretKey: Self.secret
            )
        )

        let identityId = Identity.ID(UUID())
        let issued = try await client.generateAccess(
            identityId,
            try EmailAddress("holder@example.com"),
            1
        )
        let verified = try await client.verifyAccess(issued)

        #expect(verified.identityId == identityId)
    }
}
