import Foundation
import JWT
import RFC_7519

extension Identity.Token {
    /// The signing discipline every identity token is issued and verified under.
    ///
    /// Issuing and verification both name ``algorithm`` explicitly, so the `alg`
    /// header a presented token carries never selects the verifier.
    public enum Signing {}
}

extension Identity.Token.Signing {
    /// The single algorithm identity tokens are issued under.
    public static let algorithm: SigningAlgorithm = .hmacSHA256

    /// Verifies `jwt` against `key` under ``algorithm`` and validates its timing claims.
    ///
    /// - Parameters:
    ///   - jwt: The presented token.
    ///   - key: The verification key.
    /// - Returns: `true` when the signature and the timing claims both hold.
    /// - Throws: ``RFC_7519/Error``. A token declaring any algorithm other than
    ///   ``algorithm`` throws rather than verifying.
    public static func verify(
        _ jwt: JWT,
        with key: VerificationKey
    ) throws(RFC_7519.Error) -> Bool {
        try jwt.verifyAndValidate(with: key, algorithm: algorithm)
    }
}
