# swift-identities

[![CI](https://github.com/coenttb/swift-identities/workflows/CI/badge.svg)](https://github.com/coenttb/swift-identities/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

A complete, production-ready identity authentication and management system for Swift server applications.

## Overview

`swift-identities` provides a comprehensive authentication system with:

- **Complete Authentication**: Email/password, token-based, and API key authentication
- **Email Workflows**: Verification, password reset, email change with proper confirmation flows
- **Multi-Factor Authentication**: TOTP (Google Authenticator) and backup codes - production ready. SMS, Email, WebAuthn in development.
- **Token Management**: Secure token generation, validation, and lifecycle management
- **Database Integration**: Ready-to-use PostgreSQL implementation
- **Email Integration**: Pluggable email system (see [swift-identities-mailgun](https://github.com/coenttb/swift-identities-mailgun))
- **API & Web Support**: Both JSON API and HTML form handling

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-identities", from: "0.1.0")
]
```

## Quick Start

### Standalone Identity Server

The simplest way to get started is with the standalone identity server:

```swift
import Vapor
import IdentitiesStandalone
import Records
import Dependencies

// Configure your Vapor app
let app = Application()

// Set up database and identity configuration
try await withDependencies {
    // Configure database
    $0.defaultDatabase = try Database.pool(configuration: databaseConfig)

    // Configure identity
    $0[Identity.Standalone.Configuration.self] = .init(
        baseURL: URL(string: "https://identity.example.com")!,
        router: Identity.Route.Router(),
        jwt: .live(signingKey: jwtSigningKey),
        cookies: .default,
        branding: .init(appName: "My App", logoURL: nil),
        navigation: .default,
        redirect: .default,
        rateLimiters: nil,
        email: .mailgun(/* email configuration */)
    )
} operation: {
    // Run migrations and configure
    try await Identity.Standalone.configure(app, runMigrations: true)

    // Start the server
    try app.run()
}
```

### With Email Integration

For production email support, use [swift-identities-mailgun](https://github.com/coenttb/swift-identities-mailgun):

```swift
import IdentitiesMailgun

let emailConfig = Identity.Backend.Configuration.Email.mailgun(
    domain: "mg.example.com",
    apiKey: mailgunApiKey,
    fromEmail: "noreply@example.com",
    fromName: "My App"
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

The package is organized into modular components:

- **IdentitiesTypes**: Core types and protocols (from [swift-identities-types](https://github.com/coenttb/swift-identities-types))
- **IdentitiesBackend**: Database models and operations
- **IdentitiesStandalone**: Complete standalone implementation
- **IdentitiesSupport**: Shared utilities and helpers

## Database Schema

Includes migrations for:
- Identities table with email, password hash, verification status
- Tokens table with types (access, refresh, verification, reset)
- MFA settings and backup codes
- API keys with scopes
- Audit logs for security events

## Integration

### With Vapor

For a complete standalone identity server with Vapor:

```swift
import Vapor
import IdentitiesStandalone
import Records

func configure(_ app: Application) async throws {
    // Set up dependencies (database, configuration, etc.)
    // See Quick Start section for full configuration

    // Configure Identity Standalone (runs migrations, registers middleware)
    try await Identity.Standalone.configure(app, runMigrations: true)

    // Add your application routes
    // Identity handles authentication at /identity/*
}
```

For integrating identity into an existing app (Consumer mode):

```swift
import IdentitiesConsumer

// Configure consumer to talk to identity server
$0[Identity.Consumer.Configuration.self] = .init(
    identityServerURL: URL(string: "https://identity.example.com")!,
    apiKey: identityAPIKey,
    router: Identity.Route.Router()
)

// Add consumer middleware for local authentication checking
app.middleware.use(Identity.Consumer.Authenticator())
```

### With Dependencies

Uses [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) for dependency injection:

```swift
@Dependency(\.identity) var identity
@Dependency(\.defaultDatabase) var database

// Use identity operations
let authResponse = try await identity.authenticate.login(email, password)
```

## Testing

Test with dependency injection and isolated test databases:

```swift
import Testing
import Records
import Dependencies

@Test
func testAuthentication() async throws {
    try await withDependencies {
        // Each test gets isolated database schema
        $0.defaultDatabase = try Database.testPool()
        $0[Identity.Backend.Configuration.self] = .testValue
    } operation: {
        @Dependency(\.defaultDatabase) var db

        // Create test identity
        let identity = try await db.write { db in
            try await Identity.Record
                .insert { Identity.Record.Draft(email: "test@example.com", passwordHash: hash) }
                .returning(\.self)
                .fetchOne(db)
        }

        // Test authentication logic
        #expect(identity != nil)
    }
}
```

## Related Packages

### Dependencies

- [swift-html](https://github.com/coenttb/swift-html): The Swift library for domain-accurate and type-safe HTML & CSS.
- [swift-identities-types](https://github.com/coenttb/swift-identities-types): A Swift package with foundational types for authentication.
- [swift-one-time-password](https://github.com/coenttb/swift-one-time-password): A Swift package for TOTP and HOTP two-factor authentication.
- [swift-records](https://github.com/coenttb/swift-records): The Swift library for PostgreSQL database operations.
- [swift-server-foundation-vapor](https://github.com/coenttb/swift-server-foundation-vapor): A Swift package integrating swift-server-foundation with Vapor.

### Used By

- [swift-identities-mailgun](https://github.com/coenttb/swift-identities-mailgun): A Swift package integrating Mailgun with swift-identities.

### Third-Party Dependencies

- [pointfreeco/swift-dependencies](https://github.com/pointfreeco/swift-dependencies): A dependency management library for controlling dependencies in Swift.

## Requirements

- Swift 6.0+
- macOS 14+ / Linux
- PostgreSQL 13+ (for database backend)

## License

This package is licensed under the AGPL 3.0 License. See [LICENSE.md](LICENSE.md) for details.

For commercial licensing options, please contact the maintainer.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/coenttb/swift-identities).