import Dependencies
import Foundation
import IdentitiesTypes

// MARK: - Test Implementation
// The Client type is now defined in swift-identities-types
// Configuration moved to Identity Backend

extension Identity.MFA.TOTP.Client: @retroactive Dependency.Key.Test {
    public static var testValue: Self {
        // @Witness generates no zero-arg init; `.unimplemented()` yields a
        // witness whose endpoints throw Witness.Unimplemented.Error.
        Self.unimplemented()
    }
}

// MARK: - Dependency Values

extension Dependency.Values {
    public var totpClient: Identity.MFA.TOTP.Client {
        get { self[Identity.MFA.TOTP.Client.self] }
        set { self[Identity.MFA.TOTP.Client.self] = newValue }
    }
}
