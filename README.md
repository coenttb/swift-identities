# swift-authentication

[![CI](https://github.com/swift-foundations/swift-authentication/workflows/CI/badge.svg)](https://github.com/swift-foundations/swift-authentication/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

An identity authentication and management system for Swift server applications. Email/password
and token-based authentication, TOTP, and backup codes are production ready; SMS, Email, and
WebAuthn multi-factor authentication have configuration infrastructure in place but not yet
implemented verification logic — see the Multi-Factor Authentication section below.

## Overview

`swift-authentication` provides a comprehensive authentication system with:

- **Complete Authentication**: Email/password, token-based, and API key authentication
- **Email Workflows**: Verification, password reset, email change with proper confirmation flows
- **Multi-Factor Authentication**: TOTP (Google Authenticator) and backup codes - production ready. SMS, Email, WebAuthn in development.
- **Token Management**: Secure token generation, validation, and lifecycle management
- **Database Integration**: Ready-to-use PostgreSQL implementation (via [swift-records](https://github.com/swift-foundations/swift-records))
- **Email Integration**: A closure-based `Identity.Backend.Configuration.Email` you wire to any provider
- **API & Web Support**: Both JSON API and HTML form handling

## Installation

`swift-authentication` is pre-release; pin to `branch: "main"` until the first tag:

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-authentication.git", branch: "main")
]
```

Then add the product(s) you need to your target. The currently vended products are `Identity
Shared`, `Identity Backend`, `Identity Provider`, `Identity Views`, `Identity Consumer`, and
`Identity Frontend` — each imports under its underscored module name (for example `Identity
Provider` imports as `Identity_Provider`):

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Identity Provider", package: "swift-authentication")
    ]
)
```

> `Identity Standalone` exists in `Sources/` but its target is currently commented out of
> `Package.swift` — it does not compile against the institute-only dependency graph yet and is
> held for a ruling. Do not depend on it until it is re-enabled as a product.

## Quick Start

Every request runs against an injected `Identity.Provider.Configuration` (and, for the backend
storage layer, `Identity.Backend.Configuration`). `.testValue` gives you a working in-memory
configuration to explore the API immediately:

```swift
import Dependencies
import Identity_Provider

try await withDependencies {
    $0[Identity.Provider.Configuration.self] = .testValue
} operation: {
    // Your app code (Vapor routes, migrations, middleware) runs here with
    // Identity Provider configured.
}
```

For production, replace `.testValue` with your own `Identity.Provider.Configuration` (base URL,
token lifetimes, and the Identity Provider's own API router) and `Identity.Backend.Configuration`
(a JWT `Identity.Token.Client`, a database-backed router, and the `Email` callbacks that send your
verification, password-reset, and change-notification messages):

```swift
import Identity_Backend

let backendConfiguration = Identity.Backend.Configuration(
    jwt: .test(),                                  // or `.live(signingKey:)` in production
    router: Identity.Authentication.Route.Router(),
    email: .noop                                    // supply real callbacks in production
)
```

## Features

### Authentication Methods

- **Email & Password**: Traditional authentication with secure password hashing
- **Token-Based**: Bearer tokens for API authentication
- **API Keys**: Long-lived keys for service-to-service communication
- **Session Management**: Secure session handling with automatic expiry

### Multi-Factor Authentication (MFA)

- **TOTP**: ✅ Time-based one-time passwords (Google Authenticator, etc.) - **Production Ready**
- **Backup Codes**: ✅ Recovery codes for when primary MFA is unavailable - **Production Ready**
- **SMS**: 🚧 Text message verification codes - **In Development**
- **Email**: 🚧 Email-based verification codes - **In Development**
- **WebAuthn**: 🚧 Hardware security keys and biometric authentication - **Planned**

> **Note**: Currently, only TOTP and Backup Codes are fully implemented and production-ready. SMS, Email, and WebAuthn MFA methods have configuration infrastructure in place but require implementation of the verification logic.

### Security Features

- Password strength requirements
- Rate limiting for authentication attempts
- Secure token generation and storage
- CSRF protection for web forms
- Automatic session invalidation
- Account lockout policies

## Architecture

The package is organized into modular products:

- **Identity Shared** (`Identity_Shared`): Core session, token, and cookie primitives shared by every other product.
- **Identity Backend** (`Identity_Backend`): Database-backed storage, password hashing, MFA, and email-workflow implementation.
- **Identity Provider** (`Identity_Provider`): The HTTP API surface that exposes Identity Backend to clients.
- **Identity Views** (`Identity_Views`): The HTML view layer, built on `swift-html` and `swift-webpage`.
- **Identity Frontend** (`Identity_Frontend`): A session-aware frontend surface built on Identity Views.
- **Identity Consumer** (`Identity_Consumer`): Client-side integration for apps that authenticate against a remote Identity Provider.

Foundational types (`Identity`, `Identity.ID`, and related protocols) come from
[swift-identities-types](https://github.com/swift-foundations/swift-identities-types), imported as
`IdentitiesTypes`.

## Database Schema

Includes migrations for:
- Identities table with email, password hash, verification status
- Tokens table with types (access, refresh, verification, reset)
- MFA settings and backup codes
- API keys with scopes
- Audit logs for security events

## Integration

### With Vapor

```swift
import Dependencies
import Identity_Backend
import Identity_Provider
import Vapor

func configure(_ app: Application) async throws {
    try await withDependencies {
        $0[Identity.Backend.Configuration.self] = backendConfiguration
        $0[Identity.Provider.Configuration.self] = providerConfiguration
    } operation: {
        // Register Identity Provider's routes and middleware on `app`.
    }
}
```

For integrating identity into an existing app (Consumer mode), depend on `Identity Consumer`
(`import Identity_Consumer`) and configure it against your Identity Provider's base URL the same
way, via `withDependencies`.

### With Dependencies

Uses [swift-dependencies](https://github.com/swift-foundations/swift-dependencies) (the
institute's fork of [pointfreeco/swift-dependencies](https://github.com/pointfreeco/swift-dependencies))
for dependency injection, as shown in the Quick Start above.

## Testing

Test with dependency injection, following the same pattern used throughout this package's own
test suite:

```swift
import Dependencies
import Identity_Provider
import Testing

@Test
func testProviderConfiguration() async throws {
    try await withDependencies {
        $0[Identity.Provider.Configuration.self] = .testValue
    } operation: {
        @Dependency(\.identityProviderConfiguration) var configuration
        #expect(configuration.provider.baseURL.absoluteString == "/")
    }
}
```

## Related Packages

### Institute Dependencies

- [swift-identities-types](https://github.com/swift-foundations/swift-identities-types): Type-safe identity authentication and management types with dependency injection and URL routing for Swift.
- [swift-time-based-one-time-password](https://github.com/swift-foundations/swift-time-based-one-time-password): TOTP and HOTP one-time password generation per RFC 6238 and RFC 4226 for Swift.
- [swift-records](https://github.com/swift-foundations/swift-records): Type-safe, high-level PostgreSQL database abstraction built on StructuredQueries and PostgresNIO for Swift.
- [swift-html](https://github.com/swift-foundations/swift-html): Type-safe HTML generation grounded in WHATWG and W3C specifications for Swift.
- [swift-dependencies](https://github.com/swift-foundations/swift-dependencies): Type-safe dependency injection via a property wrapper with live, preview, and test resolution and scoped overrides for Swift.
- [swift-server](https://github.com/swift-foundations/swift-server): External-engine membrane for the Swift Institute server runtime — wraps Vapor, PostgresNIO, vapor/queues, and AsyncHTTPClient behind a Foundation-free institute surface.

### Third-Party Dependencies

- [vapor/vapor](https://github.com/vapor/vapor): A server-side Swift HTTP web framework.
- [apple/swift-log](https://github.com/apple/swift-log): A logging API for Swift.

## Requirements

- Swift 6.3+ (tools version 6.3.3)
- macOS 26+ / iOS 26+, and Linux for server deployments
- PostgreSQL 13+ (for the database backend)

## License

This package is licensed under the AGPL 3.0 License. See [LICENSE.md](LICENSE.md) for details.

For commercial licensing options, please contact the maintainer.

## Support

For issues, questions, or contributions, please visit the
[GitHub repository](https://github.com/swift-foundations/swift-authentication).
