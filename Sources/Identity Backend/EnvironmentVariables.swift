import Dependencies
import Foundation
import EnvironmentVariables

extension EnvVars {
    package var encryptionKey: String {
        get { self["IDENTITIES_ENCRYPTION_KEY"]! }
        set { self["IDENTITIES_ENCRYPTION_KEY"]! = newValue }
    }
    
    public var identitiesIssuer: String {
        get { self["IDENTITIES_ISSUER"]! }
        set { self["IDENTITIES_ISSUER"]! = newValue }
    }
    
    package var identitiesAudience: String {
        get { self["IDENTITIES_AUDIENCE"]! }
        set { self["IDENTITIES_AUDIENCE"]! = newValue }
    }
    
    public var identitiesMFATimeWindow: Int {
        get { self["IDENTITIES_MFA_TIME_WINDOW"].flatMap(Int.init)! }
        set { self["IDENTITIES_MFA_TIME_WINDOW"]! = newValue.description }
    }
    
    package var identitiesJWTAccessExpiry: TimeInterval {
        get { self["IDENTITIES_JWT_ACCESS_EXPIRY"].flatMap(Int.init).map(TimeInterval.init)! }
        set { self["IDENTITIES_JWT_ACCESS_EXPIRY"]! = newValue.description }
    }
    
    package var identitiesJWTRefreshExpiry: TimeInterval {
        get { self["IDENTITIES_JWT_REFRESH_EXPIRY"].flatMap(Int.init).map(TimeInterval.init)! }
        set { self["IDENTITIES_JWT_REFRESH_EXPIRY"]! = newValue.description }
    }
    
    package var identitiesJWTReauthorizationExpiry: TimeInterval {
        get { self["IDENTITIES_JWT_REAUTHORIZATION_EXPIRY"].flatMap(Int.init).map(TimeInterval.init)! }
        set { self["IDENTITIES_JWT_REAUTHORIZATION_EXPIRY"]! = newValue.description }
    }
}
