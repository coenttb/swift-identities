import Foundation
import IdentitiesTypes
import Dependencies

extension Identity.MFA.TOTP.Client {
    /// Creates a live backend implementation of the TOTP client
    public static func live(
        configuration: Identity.MFA.TOTP.Configuration
    ) -> Self {
        // Use the existing backend implementation which has all the correct imports and logic
        return .backend(configuration: configuration)
    }
}