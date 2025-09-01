import Dependencies
import DependenciesMacros
import Foundation
import JWT
import ServerFoundation
import Crypto

extension Identity.Token {
    /// Client for managing JWT tokens with support for both old and new formats
    @DependencyClient
    public struct Client: @unchecked Sendable {
        
        // MARK: - Access Token Operations
        
        /// Generate an access token
        @DependencyEndpoint
        public var generateAccess: (
            _ identityId: UUID,
            _ email: EmailAddress,
            _ sessionVersion: Int
        ) async throws -> String
        
        /// Parse and verify an access token
        @DependencyEndpoint
        public var verifyAccess: (_ token: String) async throws -> Identity.Token.Access
        
        // MARK: - Refresh Token Operations
        
        /// Generate a refresh token
        @DependencyEndpoint
        public var generateRefresh: (
            _ identityId: UUID,
            _ sessionVersion: Int
        ) async throws -> String
        
        /// Parse and verify a refresh token
        @DependencyEndpoint
        public var verifyRefresh: (_ token: String) async throws -> Identity.Token.Refresh
        
        /// Refresh an access token using a refresh token
        @DependencyEndpoint
        public var refreshAccess: (
            _ refreshToken: String,
            _ identityId: UUID,
            _ email: EmailAddress,
            _ sessionVersion: Int
        ) async throws -> String
        
        // MARK: - MFA Session Token Operations
        
        /// Generate an MFA session token
        @DependencyEndpoint
        public var generateMFASession: (
            _ identityId: UUID,
            _ sessionVersion: Int,
            _ attemptsRemaining: Int,
            _ availableMethods: [Identity.MFA.Method]
        ) async throws -> String
        
        /// Parse and verify an MFA session token
        @DependencyEndpoint
        public var verifyMFASession: (_ token: String) async throws -> Identity.Token.MFASession
        
        // MARK: - Reauthorization Token Operations
        
        /// Generate a reauthorization token
        @DependencyEndpoint
        public var generateReauthorization: (
            _ identityId: UUID,
            _ sessionVersion: Int,
            _ purpose: String,
            _ allowedOperations: [String]
        ) async throws -> String
        
        /// Parse and verify a reauthorization token
        @DependencyEndpoint
        public var verifyReauthorization: (_ token: String) async throws -> Identity.Token.Reauthorization
        
        // MARK: - Token Pair Operations
        
        /// Generate both access and refresh tokens
        @DependencyEndpoint
        public var generateTokenPair: (
            _ identityId: UUID,
            _ email: EmailAddress,
            _ sessionVersion: Int
        ) async throws -> (access: String, refresh: String)
        
        // MARK: - Generic Token Operations
        
        /// Verify any token and return its type
        @DependencyEndpoint
        public var identifyTokenType: (_ token: String) async throws -> TokenType
        
        /// Check if a token is expired without full verification
        @DependencyEndpoint
        public var isExpired: (_ token: String) async throws -> Bool
        
        public enum TokenType: String, Sendable {
            case access
            case refresh
            case reauthorization
            case unknown
        }
    }
}

// MARK: - Live Implementation

extension Identity.Token.Client {
    /// Creates a live client using the new swift-jwt implementation
    public static func live(configuration: Configuration) -> Self {
        let signingKey = SigningKey(configuration.secretKey.data(using: .utf8)!)
        let verificationKey = VerificationKey.init(configuration.secretKey.data(using: .utf8)!)
        
        return Self(
            generateAccess: { identityId, email, sessionVersion in
                let token = try Identity.Token.Access(
                    identityId: identityId,
                    email: email,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.accessTokenExpiry,
                    signingKey: signingKey
                )
                return try token.token
            },
            
            verifyAccess: { tokenString in
                let jwt = try JWT.parse(from: tokenString)
                let token = try Identity.Token.Access(jwt: jwt)
                guard try token.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                return token
            },
            
            generateRefresh: { identityId, sessionVersion in
                let token = try Identity.Token.Refresh(
                    identityId: identityId,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.refreshTokenExpiry,
                    signingKey: signingKey
                )
                return try token.token
            },
            
            verifyRefresh: { tokenString in
                let jwt = try JWT.parse(from: tokenString)
                let token = try Identity.Token.Refresh(jwt: jwt)
                guard try token.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                return token
            },
            
            refreshAccess: { refreshTokenString, identityId, email, sessionVersion in
                // Verify and parse the refresh token
                let jwt = try JWT.parse(from: refreshTokenString)
                let refreshToken = try Identity.Token.Refresh(jwt: jwt)
                
                // Verify the refresh token
                guard try refreshToken.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                
                // Verify it's not expired
                guard refreshToken.isValid else {
                    throw ClientError.tokenExpired
                }
                
                // Verify session version matches
                guard refreshToken.sessionVersion == sessionVersion else {
                    throw ClientError.sessionVersionMismatch
                }
                
                // Verify identity ID matches
                guard refreshToken.identityId == identityId else {
                    throw ClientError.identityMismatch
                }
                
                // Generate new access token
                let newToken = try Identity.Token.Access(
                    identityId: identityId,
                    email: email,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.accessTokenExpiry,
                    signingKey: signingKey
                )
                return try newToken.token
            },
            
            generateMFASession: { identityId, sessionVersion, attemptsRemaining, availableMethods in
                let token = try Identity.Token.MFASession(
                    identityId: identityId,
                    sessionVersion: sessionVersion,
                    attemptsRemaining: attemptsRemaining,
                    availableMethods: availableMethods,
                    issuer: configuration.issuer,
                    expiresIn: 300, // 5 minutes for MFA
                    signingKey: signingKey
                )
                return try token.token
            },
            
            verifyMFASession: { tokenString in
                let jwt = try JWT.parse(from: tokenString)
                let token = try Identity.Token.MFASession(jwt: jwt)
                guard try token.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                return token
            },
            
            generateReauthorization: { identityId, sessionVersion, purpose, allowedOperations in
                let token = try Identity.Token.Reauthorization(
                    identityId: identityId,
                    sessionVersion: sessionVersion,
                    purpose: purpose,
                    allowedOperations: allowedOperations,
                    issuer: configuration.issuer,
                    expiresIn: configuration.reauthorizationTokenExpiry,
                    signingKey: signingKey
                )
                return try token.token
            },
            
            verifyReauthorization: { tokenString in
                let jwt = try JWT.parse(from: tokenString)
                let token = try Identity.Token.Reauthorization(jwt: jwt)
                guard try token.verify(with: verificationKey) else {
                    throw ClientError.verificationFailed
                }
                return token
            },
            
            generateTokenPair: { identityId, email, sessionVersion in
                let accessToken = try Identity.Token.Access(
                    identityId: identityId,
                    email: email,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.accessTokenExpiry,
                    signingKey: signingKey
                )
                
                let refreshToken = try Identity.Token.Refresh(
                    identityId: identityId,
                    sessionVersion: sessionVersion,
                    issuer: configuration.issuer,
                    expiresIn: configuration.refreshTokenExpiry,
                    signingKey: signingKey
                )
                
                return (try accessToken.token, try refreshToken.token)
            },
            
            identifyTokenType: { tokenString in
                guard let jwt = try? JWT.parse(from: tokenString) else {
                    return .unknown
                }
                
                let type = jwt.payload.additionalClaim("type", as: String.self)
                switch type {
                case "access": return .access
                case "refresh": return .refresh
                case "reauth": return .reauthorization
                default: return .unknown
                }
            },
            
            isExpired: { tokenString in
                guard let jwt = try? JWT.parse(from: tokenString) else {
                    return true
                }
                if let exp = jwt.payload.exp {
                    return Date() > exp
                }
                return false
            }
        )
    }
    
    /// Configuration for the token client
    public struct Configuration: Sendable {
        public let issuer: String
        public let audience: String?
        public let secretKey: String
        public let accessTokenExpiry: TimeInterval
        public let refreshTokenExpiry: TimeInterval
        public let reauthorizationTokenExpiry: TimeInterval
        
        public init(
            issuer: String,
            audience: String? = nil,
            secretKey: String,
            accessTokenExpiry: TimeInterval = 900, // 15 minutes
            refreshTokenExpiry: TimeInterval = 2592000, // 30 days
            reauthorizationTokenExpiry: TimeInterval = 300 // 5 minutes
        ) {
            self.issuer = issuer
            self.audience = audience
            self.secretKey = secretKey
            self.accessTokenExpiry = accessTokenExpiry
            self.refreshTokenExpiry = refreshTokenExpiry
            self.reauthorizationTokenExpiry = reauthorizationTokenExpiry
        }
    }
}

// MARK: - Errors

extension Identity.Token.Client {
    public enum ClientError: Swift.Error {
        case invalidTokenFormat
        case verificationFailed
        case tokenExpired
        case sessionVersionMismatch
        case identityMismatch
        case invalidTokenClaims
    }
}

// MARK: - Test Implementation

extension Identity.Token.Client: TestDependencyKey {
    public static var testValue: Self {
        Self.live(configuration: .init(
            issuer: "test-issuer",
            audience: "test-audience",
            secretKey: "test-secret-key-that-is-at-least-32-bytes-long-for-hmac"
        ))
    }
}

// MARK: - Dependency Values

extension DependencyValues {
    public var tokenClient: Identity.Token.Client {
        get { self[Identity.Token.Client.self] }
        set { self[Identity.Token.Client.self] = newValue }
    }
}
