# Swift Identities - Comprehensive Testing Strategy

## Overview
Based on swift-records testing patterns, we'll use:
- **RecordsTestSupport**: Provides `Database.TestDatabase` with schema isolation
- **DependenciesTestSupport**: For dependency injection in tests
- **Swift Testing**: Modern testing framework (not XCTest)

## Test Structure

### 1. Backend Tests (Core Business Logic)
**Location**: `Tests/Identity Backend Tests/`

#### Authentication Tests
- ✅ Credentials authentication (email + password)
- ✅ Token-based authentication (access/refresh)
- ✅ API key authentication
- ✅ Session version validation
- ✅ Invalid credentials handling
- ✅ Locked account handling

#### Creation Tests
- ✅ Account creation request
- ✅ Email verification flow
- ✅ Duplicate email prevention
- ✅ Password validation
- ✅ Rate limiting

#### Email Tests
- ✅ Email change request
- ✅ Email change confirmation
- ✅ Duplicate email during change
- ✅ Token expiration
- ✅ Concurrent change requests

#### Password Tests
- ✅ Password reset request
- ✅ Password reset confirmation
- ✅ Password change (authenticated)
- ✅ Old password validation
- ✅ Password strength requirements

#### Deletion Tests
- ✅ Account deletion request
- ✅ Grace period handling
- ✅ Deletion cancellation
- ✅ Deletion confirmation
- ✅ Permanent deletion

#### MFA Tests
- ✅ TOTP setup
- ✅ TOTP verification
- ✅ Backup code generation
- ✅ Backup code usage
- ✅ MFA enforcement

#### Token Tests
- ✅ JWT token generation
- ✅ Token validation
- ✅ Token refresh
- ✅ Token revocation
- ✅ Session version increment

### 2. Database Integration Tests
**Location**: `Tests/Identity Backend Tests/Database/`

#### Record Tests
- ✅ Identity.Record CRUD operations
- ✅ Query builders (findByEmail, etc.)
- ✅ Unique constraints
- ✅ Timestamps (createdAt, updatedAt)

#### Migration Tests
- ✅ All migrations run successfully
- ✅ Schema matches expected structure
- ✅ Indexes created correctly
- ✅ Foreign keys enforced

#### Transaction Tests
- ✅ Rollback on error
- ✅ Atomic operations
- ✅ Concurrent writes
- ✅ Deadlock prevention

### 3. Consumer Tests
**Location**: `Tests/Identity Consumer Tests/`

#### Route Tests
- ✅ All routes parse correctly
- ✅ URL generation
- ✅ Query parameters
- ✅ Path parameters

#### Middleware Tests
- ✅ Authentication middleware
- ✅ Cookie handling
- ✅ CSRF protection
- ✅ Rate limiting

#### Response Tests
- ✅ HTML rendering
- ✅ Form handling
- ✅ Error responses
- ✅ Redirects

### 4. Provider Tests
**Location**: `Tests/Identity Provider Tests/`

#### API Tests
- ✅ All endpoints respond correctly
- ✅ JSON serialization
- ✅ Error handling
- ✅ Rate limiting

#### Authentication Tests
- ✅ Bearer token validation
- ✅ API key validation
- ✅ Token refresh flow

### 5. Standalone Tests
**Location**: `Tests/Identity Standalone Tests/`

#### Integration Tests
- ✅ Full authentication flow
- ✅ End-to-end user journey
- ✅ Configuration loading
- ✅ Environment variables

## Test Patterns

### Database Test Pattern
```swift
@Suite(
    "Authentication Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = try await Database.TestDatabase.withIdentitySchema()
    }
)
struct AuthenticationTests {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.identity) var identity

    @Test("Authenticate with valid credentials")
    func testValidCredentials() async throws {
        // Arrange: Insert test user
        let email = EmailAddress("test@example.com")
        let password = "SecurePassword123!"

        try await database.write { db in
            try await Identity.Record.insert {
                Identity.Record.Draft(
                    email: email,
                    passwordHash: try Bcrypt.hash(password)
                )
            }.execute(db)
        }

        // Act: Authenticate
        let result = try await identity.authenticate.credentials(
            Credentials(email: email, password: password)
        )

        // Assert
        #expect(result.accessToken != nil)
        #expect(result.refreshToken != nil)
    }
}
```

### Client Test Pattern (No Database)
```swift
@Suite("Password Validation")
struct PasswordValidationTests {
    @Test("Reject weak passwords")
    func testWeakPassword() {
        let weak = "12345"
        #expect(throws: ValidationError.self) {
            try validatePassword(weak)
        }
    }
}
```

## Test Utilities

### TestDatabase Extension
```swift
extension Database {
    static func withIdentitySchema() async throws -> TestDatabase {
        let db = try await TestDatabase()

        // Run migrations
        try await db.write { conn in
            try await Identity.Backend.Migrator.runMigrations(on: conn)
        }

        return db
    }
}
```

### Test Fixtures
```swift
extension Identity.Record {
    static func testUser(
        email: EmailAddress = "test@example.com",
        verified: Bool = true
    ) async throws -> Identity.Record {
        // Create and return test user
    }
}
```

## Implementation Priority

1. **Phase 1: Core Backend** (Week 1)
   - Authentication tests
   - Creation tests
   - Database integration tests

2. **Phase 2: Features** (Week 2)
   - Email tests
   - Password tests
   - Deletion tests

3. **Phase 3: Advanced** (Week 3)
   - MFA tests
   - OAuth tests
   - Token tests

4. **Phase 4: Deployments** (Week 4)
   - Consumer tests
   - Provider tests
   - Standalone tests

## Coverage Goals

- **Unit Test Coverage**: 80%+
- **Integration Test Coverage**: 60%+
- **Critical Path Coverage**: 100%
  - Authentication
  - Account creation
  - Password reset
  - Email verification

## Running Tests

```bash
# Run all tests
swift test

# Run specific suite
swift test --filter AuthenticationTests

# Run with parallel execution
swift test --parallel

# Run with coverage
swift test --enable-code-coverage
```

## CI/CD Integration

Tests run on:
- Every commit
- Every PR
- Nightly builds
- Release candidates

## Next Steps

1. Update Package.swift with test dependencies
2. Create test utilities and fixtures
3. Implement Phase 1 tests
4. Set up CI configuration
