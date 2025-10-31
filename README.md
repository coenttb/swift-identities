# swift-identities

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-AGPL%203.0-blue.svg)](LICENSE.md)
[![Version](https://img.shields.io/badge/version-0.1.0-green.svg)](https://github.com/coenttb/swift-identities/releases)

A complete, production-ready identity authentication and management system for Swift server applications.

## Overview

`swift-identities` provides a comprehensive authentication system with:

- 🔐 **Complete Authentication**: Email/password, token-based, and API key authentication
- 📧 **Email Workflows**: Verification, password reset, email change with proper confirmation flows
- 🔑 **Multi-Factor Authentication**: Support for TOTP, SMS, Email, WebAuthn, and backup codes
- 🎫 **Token Management**: Secure token generation, validation, and lifecycle management
- 🗄️ **Database Integration**: Ready-to-use PostgreSQL implementation
- 📨 **Email Integration**: Pluggable email system (see [swift-identities-mailgun](https://github.com/coenttb/swift-identities-mailgun))
- 🌐 **API & Web Support**: Both JSON API and HTML form handling

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-identities", from: "0.1.0")
]
```

## Quick Start

### Basic Setup

```swift
import Identities
import IdentitiesBackend

// Configure your identity system
let identityConfig = Identity.Configuration(
    requireEmailVerification: true,
    allowPasswordReset: true,
    tokenLifetime: .hours(24)
)

// Initialize with database
let identitySystem = try Identity.System(
    database: database,
    configuration: identityConfig
)
```

### With Email Integration

For production email support, use [swift-identities-mailgun](https://github.com/coenttb/swift-identities-mailgun):

```swift
import IdentitiesMailgunLive

let identityClient = Identity.Client.mailgun(
    business: businessDetails,
    router: identityRouter
)
```

## Features

### Authentication Methods

- **Email & Password**: Traditional authentication with secure password hashing
- **Token-Based**: Bearer tokens for API authentication
- **API Keys**: Long-lived keys for service-to-service communication
- **Session Management**: Secure session handling with automatic expiry

### Multi-Factor Authentication (MFA)

- **TOTP**: Time-based one-time passwords (Google Authenticator, etc.)
- **SMS**: Text message verification codes
- **Email**: Email-based verification codes
- **WebAuthn**: Hardware security keys and biometric authentication
- **Backup Codes**: Recovery codes for when primary MFA is unavailable

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

```swift
import Vapor
import Identities

func configure(_ app: Application) throws {
    // Add identity routes
    try app.register(collection: IdentityController())
    
    // Add authentication middleware
    app.middleware.use(Identity.TokenAuthenticator())
}
```

### With Dependencies

Uses [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) for dependency injection:

```swift
@Dependency(\.identityClient) var identityClient
```

## Testing

Includes comprehensive test utilities:

```swift
import IdentitiesTestSupport

@Test
func testAuthentication() async throws {
    let testDB = Identity.TestDatabase()
    let identity = try await testDB.createVerifiedIdentity()
    // Test your authentication logic
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