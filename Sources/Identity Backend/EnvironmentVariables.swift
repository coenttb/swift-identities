import Dependencies
import Foundation
import EnvironmentVariables

extension EnvVars {
    /// Encryption key for sensitive data (TOTP secrets, OAuth tokens)
    /// ⚠️ SECURITY: Empty string in development mode = no encryption
    /// Production MUST set IDENTITIES_ENCRYPTION_KEY
    package var encryptionKey: String {
        get { self["IDENTITIES_ENCRYPTION_KEY"] ?? "" }
        set { self["IDENTITIES_ENCRYPTION_KEY"] = newValue }
    }

    /// JWT issuer claim - identifies the token issuer
    /// Defaults to "swift-identities" for development
    public var identitiesIssuer: String {
        get { self["IDENTITIES_ISSUER"] ?? "swift-identities" }
        set { self["IDENTITIES_ISSUER"] = newValue }
    }

    /// JWT audience claim - identifies the intended token recipient
    /// Defaults to "swift-identities" for development
    package var identitiesAudience: String {
        get { self["IDENTITIES_AUDIENCE"] ?? "swift-identities" }
        set { self["IDENTITIES_AUDIENCE"] = newValue }
    }

    /// MFA time window for TOTP validation (in 30-second periods)
    /// Default: 1 = ±30 seconds (current + 1 before/after)
    public var identitiesMFATimeWindow: Int {
        get { self["IDENTITIES_MFA_TIME_WINDOW"].flatMap(Int.init) ?? 1 }
        set { self["IDENTITIES_MFA_TIME_WINDOW"] = newValue.description }
    }

    /// Access token expiry in seconds
    /// Default: 900 seconds (15 minutes)
    package var identitiesJWTAccessExpiry: TimeInterval {
        get { self["IDENTITIES_JWT_ACCESS_EXPIRY"].flatMap(Int.init).map(TimeInterval.init) ?? 900 }
        set { self["IDENTITIES_JWT_ACCESS_EXPIRY"] = newValue.description }
    }

    /// Refresh token expiry in seconds
    /// Default: 2592000 seconds (30 days)
    package var identitiesJWTRefreshExpiry: TimeInterval {
        get { self["IDENTITIES_JWT_REFRESH_EXPIRY"].flatMap(Int.init).map(TimeInterval.init) ?? 2592000 }
        set { self["IDENTITIES_JWT_REFRESH_EXPIRY"] = newValue.description }
    }

    /// Reauthorization token expiry in seconds (for sensitive operations)
    /// Default: 300 seconds (5 minutes)
    package var identitiesJWTReauthorizationExpiry: TimeInterval {
        get { self["IDENTITIES_JWT_REAUTHORIZATION_EXPIRY"].flatMap(Int.init).map(TimeInterval.init) ?? 300 }
        set { self["IDENTITIES_JWT_REAUTHORIZATION_EXPIRY"] = newValue.description }
    }

    /// Bcrypt cost factor for password hashing
    /// Default: 10 (good balance for production)
    /// Development: use 8 for faster tests
    /// Production: consider 11-12 for higher security
    package var bcryptCost: Int {
        get { self["BCRYPT_COST"].flatMap(Int.init) ?? 10 }
        set { self["BCRYPT_COST"] = newValue.description }
    }
}
