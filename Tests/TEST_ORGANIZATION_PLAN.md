# Test Organization Plan for swift-identities

## Source Targets Overview

Based on `Package.swift`:
1. **Identity Backend** - Core database and business logic
2. **Identity Shared** - Shared types, tokens, utilities
3. **Identity Frontend** - HTTP handlers and responses
4. **Identity Views** - HTML/view components
5. **Identity Consumer** - Consumer-specific functionality
6. **Identity Provider** - Provider-specific functionality
7. **Identity Standalone** - Standalone server

## Test Target Structure (Following swift-records Pattern)

```
Tests/
├── Identity Backend Tests/          # Primary focus - database & business logic
│   ├── Integration/
│   │   ├── Authentication/
│   │   │   ├── AuthenticationTests.swift           ✓ EXISTS (improved)
│   │   │   ├── PasswordVerificationTests.swift     NEW
│   │   │   └── SessionManagementTests.swift        NEW
│   │   ├── Creation/
│   │   │   ├── IdentityCreationTests.swift         NEW
│   │   │   └── ConstraintViolationTests.swift      NEW
│   │   ├── MFA/
│   │   │   ├── TOTPTests.swift                     NEW
│   │   │   └── BackupCodeTests.swift               NEW
│   │   ├── Email/
│   │   │   ├── EmailVerificationTests.swift        NEW
│   │   │   └── EmailUpdateTests.swift              NEW
│   │   ├── Password/
│   │   │   ├── PasswordResetTests.swift            NEW
│   │   │   └── PasswordChangeTests.swift           NEW
│   │   ├── Profile/
│   │   │   └── ProfileUpdateTests.swift            NEW
│   │   ├── Deletion/
│   │   │   └── IdentityDeletionTests.swift         NEW
│   │   ├── OAuth/
│   │   │   └── OAuthConnectionTests.swift          NEW
│   │   ├── Token/
│   │   │   └── TokenManagementTests.swift          NEW
│   │   ├── Database/
│   │   │   └── DatabaseOperationsTests.swift       NEW
│   │   └── Transactions/
│   │       └── TransactionTests.swift              NEW
│   ├── Utilities/
│   │   ├── TestFixtures.swift                      ✓ EXISTS (improved)
│   │   ├── TestDatabase+Identity.swift             ✓ EXISTS
│   │   └── EnvironmentVariables+Development.swift  ✓ EXISTS
│   ├── TEST_PATTERNS.md                            ✓ EXISTS
│   └── IMPROVEMENTS_SUMMARY.md                     ✓ EXISTS
│
├── Identity Shared Tests/            # Token, validation, utilities
│   ├── Token/
│   │   ├── AccessTokenTests.swift                  NEW
│   │   ├── RefreshTokenTests.swift                 NEW
│   │   └── MFAChallengeTokenTests.swift            NEW
│   ├── MFA/
│   │   ├── TOTPUtilitiesTests.swift                NEW
│   │   └── TOTPValidationTests.swift               NEW
│   ├── RateLimit/
│   │   └── RateLimitTests.swift                    NEW
│   └── Utilities/
│       └── TestHelpers.swift                       NEW
│
├── Identity Frontend Tests/          # HTTP handlers and responses
│   ├── Response/
│   │   ├── AuthenticationResponseTests.swift       NEW
│   │   ├── MFAResponseTests.swift                  NEW
│   │   └── EmailResponseTests.swift                NEW
│   ├── API/
│   │   └── APIResponseTests.swift                  NEW
│   ├── Cookies/
│   │   └── CookieManagementTests.swift             NEW
│   └── Utilities/
│       └── TestHelpers.swift                       NEW
│
└── README Verification Tests/         # Documentation verification
    └── ReadmeVerificationTests.swift               ✓ EXISTS
```

## Test Priority Matrix

### Priority 1: Core Database Operations (Identity Backend)
**Essential for data integrity**

1. ✅ **Authentication** (COMPLETED)
   - [x] Create identity with password
   - [x] Password verification (correct/incorrect)
   - [x] Find by email
   - [x] Session management (lastLoginAt, sessionVersion)

2. 🔄 **Creation** (NEXT)
   - [ ] Create identity with valid data
   - [ ] Duplicate email constraint
   - [ ] Invalid email format
   - [ ] Missing required fields
   - [ ] Email verification status

3. 🔄 **MFA Operations** (HIGH PRIORITY)
   - [ ] TOTP setup and confirmation
   - [ ] TOTP code verification
   - [ ] Backup code generation
   - [ ] Backup code usage
   - [ ] MFA disable

4. 🔄 **Email Operations** (HIGH PRIORITY)
   - [ ] Email verification flow
   - [ ] Email verification token generation
   - [ ] Email verification token validation
   - [ ] Email update flow

5. 🔄 **Password Operations** (HIGH PRIORITY)
   - [ ] Password reset request
   - [ ] Password reset token validation
   - [ ] Password change with current password
   - [ ] Password change without current (via reset)

6. 🔄 **Profile Operations** (MEDIUM PRIORITY)
   - [ ] Profile data updates
   - [ ] Identity lookup operations

7. 🔄 **Deletion Operations** (MEDIUM PRIORITY)
   - [ ] Identity deletion (soft/hard)
   - [ ] Cascade deletion of related records

8. 🔄 **OAuth Operations** (MEDIUM PRIORITY)
   - [ ] OAuth connection creation
   - [ ] OAuth connection lookup
   - [ ] OAuth connection deletion

9. 🔄 **Token Management** (MEDIUM PRIORITY)
   - [ ] Token CRUD operations
   - [ ] Token expiration
   - [ ] Token revocation

10. 🔄 **Transactions** (IMPORTANT)
    - [ ] Transaction commit
    - [ ] Transaction rollback
    - [ ] Savepoint handling
    - [ ] Concurrent operations

### Priority 2: Shared Logic (Identity Shared)
**Token validation and utilities**

1. 🔄 **Access Tokens** (HIGH PRIORITY)
   - [ ] Token generation
   - [ ] Token parsing
   - [ ] Token validation
   - [ ] Token expiration

2. 🔄 **Refresh Tokens** (HIGH PRIORITY)
   - [ ] Token generation
   - [ ] Token validation
   - [ ] Token rotation

3. 🔄 **MFA Challenge Tokens** (MEDIUM PRIORITY)
   - [ ] Challenge token generation
   - [ ] Challenge token validation

4. 🔄 **TOTP Utilities** (MEDIUM PRIORITY)
   - [ ] TOTP secret generation
   - [ ] TOTP code generation
   - [ ] TOTP code validation
   - [ ] Time window validation

5. 🔄 **Rate Limiting** (MEDIUM PRIORITY)
   - [ ] Rate limit enforcement
   - [ ] Rate limit reset

### Priority 3: HTTP Layer (Identity Frontend)
**Request/response handling**

1. 🔄 **Authentication Responses** (MEDIUM PRIORITY)
   - [ ] Login response formatting
   - [ ] Logout response
   - [ ] Token refresh response

2. 🔄 **MFA Responses** (MEDIUM PRIORITY)
   - [ ] MFA challenge response
   - [ ] MFA verification response

3. 🔄 **Cookie Management** (MEDIUM PRIORITY)
   - [ ] Cookie generation
   - [ ] Cookie validation
   - [ ] Cookie deletion

## Package.swift Test Target Configuration

### Current (Single Test Target)
```swift
.testTarget(
    name: .identityBackend.tests,
    dependencies: [
        .identityBackend,
        .identitiesTypes,
        .dependenciesTestSupport,
        .product(name: "RecordsTestSupport", package: "swift-records")
    ]
)
```

### Proposed (Multiple Test Targets)
```swift
// Identity Backend Tests
.testTarget(
    name: "Identity Backend Tests",
    dependencies: [
        .identityBackend,
        .identityShared,
        .identitiesTypes,
        .dependenciesTestSupport,
        .product(name: "RecordsTestSupport", package: "swift-records")
    ]
),

// Identity Shared Tests
.testTarget(
    name: "Identity Shared Tests",
    dependencies: [
        .identityShared,
        .identitiesTypes,
        .dependenciesTestSupport,
        .serverFoundationVapor
    ]
),

// Identity Frontend Tests
.testTarget(
    name: "Identity Frontend Tests",
    dependencies: [
        .identityFrontend,
        .identityShared,
        .identityBackend,  // For integration tests
        .identitiesTypes,
        .dependenciesTestSupport,
        .serverFoundationVapor,
        .product(name: "RecordsTestSupport", package: "swift-records")
    ]
),

// README Verification Tests (existing)
.testTarget(
    name: "Readme Verification Tests",
    dependencies: [
        .identityBackend,
        .identityShared,
        .identityFrontend
    ]
)
```

## Implementation Phases

### Phase 1: Core Backend Tests ✓ COMPLETED
- [x] Authentication flow
- [x] Password verification
- [x] Basic CRUD
- [x] Test infrastructure

### Phase 2: Critical Backend Operations (THIS PHASE)
1. Creation tests with constraints
2. Transaction and rollback tests
3. MFA operations (TOTP, backup codes)
4. Email verification
5. Password reset

### Phase 3: Extended Backend Coverage
1. Profile operations
2. Deletion operations
3. OAuth connections
4. Token management

### Phase 4: Shared Logic Tests
1. Token generation/validation
2. TOTP utilities
3. Rate limiting

### Phase 5: Frontend Tests
1. Response formatting
2. Cookie management
3. API endpoints

## Test Data Management

### Fixtures Strategy
- **TestFixtures** (existing) - Core identity creation
- **MFAFixtures** (new) - TOTP secrets, backup codes
- **EmailFixtures** (new) - Email verification tokens
- **PasswordFixtures** (new) - Password reset tokens
- **OAuthFixtures** (new) - OAuth connections

### Database Isolation
- Each test suite gets isolated PostgreSQL schema
- Schema naming: `test_{uuid}` via LazyTestDatabase
- Automatic migration on setup
- Parallel test execution supported

## Code Coverage Goals

| Target | Current | Goal |
|--------|---------|------|
| Identity Backend | ~15% | 85%+ |
| Identity Shared | 0% | 75%+ |
| Identity Frontend | 0% | 60%+ |
| Overall | ~5% | 75%+ |

## Success Criteria

✅ All essential business logic tested
✅ Database constraints verified
✅ Transaction handling validated
✅ MFA flows working correctly
✅ Email verification secure
✅ Password reset secure
✅ Tests are fast (<5s for full suite)
✅ Tests can run in parallel
✅ Clear error messages on failure
✅ Well-organized and maintainable
