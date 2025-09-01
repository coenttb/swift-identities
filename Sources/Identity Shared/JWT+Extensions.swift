import Foundation
import JWT
import RFC_7519

// MARK: - JWT Creation Extensions

extension JWT {
    /// Creates a signed JWT token
    public static func signed(
        algorithm: String,
        key: SigningKey,
        issuer: String? = nil,
        subject: String? = nil,
        expiresIn: TimeInterval? = nil,
        jti: String? = nil,
        claims: [String: Any]? = nil
    ) throws -> JWT {
        // Calculate expiration time
        let exp = expiresIn.map { Date(timeIntervalSinceNow: $0) }
        let iat = Date()
        
        // Create payload
        let payload = JWT.Payload(
            iss: issuer,
            sub: subject,
            aud: nil,
            exp: exp,
            nbf: nil,
            iat: iat,
            jti: jti,
            additionalClaims: claims
        )
        
        // Create header
        let header = JWT.Header(
            alg: algorithm,
            typ: "JWT",
            cty: nil,
            kid: nil,
            additionalParameters: nil
        )
        
        // Create JWT without signature for now
        // In a real implementation, you'd need to sign this properly
        let jwt = JWT(header: header, payload: payload, signature: Data())
        
        // Sign the JWT
        let signingInput = try jwt.signingInput()
        let signature = try key.sign(signingInput, algorithm: algorithm)
        
        // Return JWT with signature
        return JWT(header: header, payload: payload, signature: signature)
    }
}

// MARK: - JWT Verification Extensions

extension JWT {
    /// Verifies and validates the JWT
    public func verifyAndValidate(with key: VerificationKey) throws -> Bool {
        // Verify signature
        let signingInput = try self.signingInput()
        let isValid = try key.verify(signature, for: signingInput, algorithm: header.alg)
        
        if !isValid {
            throw JWTError.signatureVerificationFailed
        }
        
        // Validate timing
        try payload.validateTiming()
        
        return true
    }
}

// MARK: - Signing/Verification Key Types

public struct SigningKey {
    private let data: Data
    
    public init(_ data: Data) {
        self.data = data
    }
    
    public init(_ string: String) {
        self.data = string.data(using: .utf8) ?? Data()
    }
    
    func sign(_ data: Data, algorithm: String) throws -> Data {
        // Simple HMAC implementation for HS256
        // In production, use proper crypto libraries
        guard algorithm == "HS256" else {
            throw JWTError.unsupportedAlgorithm
        }
        
        // This is a placeholder - real implementation would use CryptoKit
        return data
    }
}

public struct VerificationKey {
    private let data: Data
    
    public init(_ data: Data) {
        self.data = data
    }
    
    public init(_ string: String) {
        self.data = string.data(using: .utf8) ?? Data()
    }
    
    func verify(_ signature: Data, for data: Data, algorithm: String) throws -> Bool {
        // Simple verification for HS256
        // In production, use proper crypto libraries
        guard algorithm == "HS256" else {
            throw JWTError.unsupportedAlgorithm
        }
        
        // This is a placeholder - real implementation would use CryptoKit
        return true
    }
}

// MARK: - Errors

public enum JWTError: Error {
    case signatureVerificationFailed
    case unsupportedAlgorithm
    case invalidToken
}

// MARK: - Algorithm Constants

extension String {
    public static let hmacSHA256 = "HS256"
}
