import Dependencies
import DependenciesMacros
import Foundation
import IdentitiesTypes

// MARK: - Test Implementation
// The Client type is now defined in swift-identities-types
// Configuration moved to Identity Backend

extension Identity.MFA.TOTP.Client: @retroactive TestDependencyKey {
  public static var testValue: Self {
    Self()
  }
}

// MARK: - Dependency Values

extension DependencyValues {
  public var totpClient: Identity.MFA.TOTP.Client {
    get { self[Identity.MFA.TOTP.Client.self] }
    set { self[Identity.MFA.TOTP.Client.self] = newValue }
  }
}
