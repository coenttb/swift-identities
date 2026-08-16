import Dependencies
import TOTP

extension Identity.MFA.TOTP {
    /// The seam through which submitted TOTP codes are checked against a generator.
    ///
    /// The live value performs real RFC 6238 validation, and so does the test
    /// value: verification fails closed everywhere. Tests that need a
    /// deterministic outcome inject their own verifier with `withDependencies`
    /// instead of relying on a hardcoded bypass code.
    package struct Verifier: Sendable {
        package var validate: @Sendable (_ code: String, _ totp: TOTP, _ window: Int) -> Bool

        package init(
            validate: @escaping @Sendable (_ code: String, _ totp: TOTP, _ window: Int) -> Bool
        ) {
            self.validate = validate
        }
    }
}

extension Identity.MFA.TOTP.Verifier: Dependency.Key {
    package static let liveValue: Identity.MFA.TOTP.Verifier = .init { code, totp, window in
        totp.validate(code, window: window)
    }

    package static let testValue: Identity.MFA.TOTP.Verifier = .liveValue
}
