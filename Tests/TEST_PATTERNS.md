# Test Pattern Improvements for swift-identities

This document outlines improvements to adopt from swift-records test patterns.

## Current State Analysis

### ✅ What We're Already Doing Well

1. **Swift Testing Framework**: Using `@Test`, `@Suite`, `#expect()` ✓
2. **Dependency Injection**: Using `@Dependency(\.defaultDatabase)` at suite level ✓
3. **Suite Configuration**: Using `.dependencies { }` for setup ✓
4. **Schema Isolation**: Using `LazyTestDatabase` with isolated schemas ✓
5. **Test Naming**: Using descriptive test names with `@Test("...")` ✓
6. **Read/Write Pattern**: Properly separating `database.read` and `database.write` ✓
7. **Test Fixtures**: Using `TestFixtures` for reusable test data ✓

### ⚠️ Areas for Improvement

## 1. Test Organization and Structure

### Current Issues:
- All authentication tests in single flat file
- No subdirectory organization by test type
- Limited test coverage (only 6 tests)

### Improvements from swift-records:
```
Tests/Identity Backend Tests/
├── Integration/
│   ├── Authentication/
│   │   ├── AuthenticationTests.swift           # Basic auth flow
│   │   ├── PasswordVerificationTests.swift     # Password checks
│   │   └── SessionManagementTests.swift        # Session version, last login
│   ├── MFA/
│   │   ├── TOTPTests.swift                     # TOTP operations
│   │   └── BackupCodeTests.swift               # Backup code operations
│   ├── Database/
│   │   ├── IdentityCreationTests.swift         # CRUD operations
│   │   ├── EmailVerificationTests.swift        # Email verification flow
│   │   └── PasswordResetTests.swift            # Password reset flow
│   ├── Errors/
│   │   └── ConstraintViolationTests.swift      # Database constraints
│   └── Transactions/
│       └── TransactionTests.swift              # Transaction handling
├── Utilities/
│   ├── TestFixtures.swift                      # ✓ Already exists
│   ├── TestDatabase+Identity.swift             # ✓ Already exists
│   ├── EnvironmentVariables+Development.swift  # ✓ Already exists
│   └── AssertQuery.swift                       # NEW: Query validation helper
└── TestInfrastructure/
    └── TestDatabaseTests.swift                 # NEW: Test the test infrastructure
```

## 2. Remove Debug Code

### Current Issues:
```swift
// Lines 25-42 in AuthenticationTests.swift
do {
    let identity = try await database.write { db in
        // ... test code
    }
    // ... assertions
} catch {
    print("DEBUG: Test error: \(String(reflecting: error))")  // ❌ Remove
    throw error
}
```

### Improvement:
- **Remove `do-catch` wrapper with debug print** - Tests should fail naturally
- If debugging needed, use `Issue.record()` or breakpoints
- Let Swift Testing framework handle error reporting

**Pattern from swift-records:**
```swift
@Test("Create identity with password")
func testCreateIdentityWithPassword() async throws {
    let identity = try await database.write { db in
        try await TestFixtures.createTestIdentity(
            email: TestFixtures.testEmail,
            password: TestFixtures.testPassword,
            verified: true,
            db: db
        )
    }

    #expect(identity.email == TestFixtures.testEmail)
    #expect(identity.emailVerificationStatus == .verified)
    #expect(!identity.passwordHash.isEmpty)
}
```

## 3. Use `#require()` for Optional Unwrapping

### Current Issues:
```swift
// Line 136
.fetchOne(db)!  // ❌ Force unwrap - crashes with poor error message
```

```swift
// Lines 102-103
#expect(foundIdentity != nil)
#expect(foundIdentity?.email == TestFixtures.testEmail)  // ❌ Optional chaining in assertion
```

### Improvement:
**Pattern from swift-records:**
```swift
// Instead of force unwrap:
let identity = try #require(
    try await database.read { db in
        try await Identity.Record
            .where { $0.id.eq(id) }
            .fetchOne(db)
    }
)

// Instead of nil check + optional:
let foundIdentity = try await database.read { db in
    try await Identity.Record
        .where { $0.email.eq(TestFixtures.testEmail) }
        .fetchOne(db)
}
let unwrapped = try #require(foundIdentity)
#expect(unwrapped.email == TestFixtures.testEmail)
```

**Benefits:**
- Better error messages when nil
- Shows exact location of failure
- More idiomatic Swift Testing

## 4. Add Cleanup Pattern

### Current Issues:
- Tests create data but never clean it up
- Relies on schema isolation (which is fine)
- But explicit cleanup is better practice

### Improvement:
**Pattern from swift-records (ErrorHandlingTests.swift:412-415):**
```swift
@Test("Create and cleanup identity")
func testCreateAndCleanup() async throws {
    let identity = try await database.write { db in
        try await TestFixtures.createTestIdentity(
            email: TestFixtures.testEmail,
            password: TestFixtures.testPassword,
            db: db
        )
    }

    // ... perform test operations

    // Cleanup
    try await database.write { db in
        try await Identity.Record
            .find([identity.id])
            .delete()
            .execute(db)
    }

    // Verify cleanup
    let deleted = try await database.read { db in
        try await Identity.Record
            .where { $0.id.eq(identity.id) }
            .fetchOne(db)
    }
    #expect(deleted == nil)
}
```

**Note:** Since we use schema isolation, cleanup is optional but demonstrates good practice.

## 5. Add Error and Constraint Testing

### Current Issues:
- No tests for constraint violations
- No tests for error conditions
- No tests for edge cases

### Improvements:
**New test file: `Tests/Identity Backend Tests/Integration/Errors/ConstraintViolationTests.swift`**

```swift
import Dependencies
import DependenciesTestSupport
import EmailAddress
import Foundation
import Identity_Backend
import Records
import RecordsTestSupport
import Testing

@Suite(
    "Constraint Violation Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
    }
)
struct ConstraintViolationTests {
    @Dependency(\.defaultDatabase) var database

    @Test("Duplicate email constraint violation")
    func testDuplicateEmailViolation() async throws {
        let email = try EmailAddress("duplicate@example.com")

        // Create first identity
        _ = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: email,
                db: db
            )
        }

        // Attempt to create duplicate - should fail
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await TestFixtures.createTestIdentity(
                    email: email,
                    db: db
                )
            }
        }
    }

    @Test("Empty email constraint violation")
    func testEmptyEmailViolation() async throws {
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await Identity.Record
                    .insert {
                        Identity.Record.Draft(
                            email: EmailAddress(rawValue: ""),  // Invalid
                            passwordHash: "hash",
                            emailVerificationStatus: .pending,
                            sessionVersion: 1
                        )
                    }
                    .execute(db)
            }
        }
    }

    @Test("Invalid session version")
    func testInvalidSessionVersion() async throws {
        await #expect(throws: (any Error).self) {
            try await database.write { db in
                try await Identity.Record
                    .insert {
                        Identity.Record.Draft(
                            email: try EmailAddress("test@example.com"),
                            passwordHash: "hash",
                            emailVerificationStatus: .pending,
                            sessionVersion: -1  // Invalid
                        )
                    }
                    .execute(db)
            }
        }
    }
}
```

## 6. Add Transaction Testing

### Current Issues:
- No tests for transaction behavior
- No tests for rollback scenarios
- No tests for concurrent operations

### Improvements:
**New test file: `Tests/Identity Backend Tests/Integration/Transactions/TransactionTests.swift`**

```swift
import Dependencies
import DependenciesTestSupport
import EmailAddress
import Foundation
import Identity_Backend
import Records
import RecordsTestSupport
import Testing

@Suite(
    "Transaction Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
    }
)
struct TransactionTests {
    @Dependency(\.defaultDatabase) var database

    enum TestError: Error {
        case intentionalRollback
    }

    @Test("Transaction rollback on error")
    func testTransactionRollback() async throws {
        let countBefore = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        do {
            try await database.withTransaction { db in
                // Create identity
                _ = try await TestFixtures.createTestIdentity(
                    email: try EmailAddress("rollback@example.com"),
                    db: db
                )

                // Force error to trigger rollback
                throw TestError.intentionalRollback
            }
        } catch TestError.intentionalRollback {
            // Expected
        }

        let countAfter = try await database.read { db in
            try await Identity.Record.fetchCount(db)
        }

        #expect(countBefore == countAfter)
    }

    @Test("Transaction commit success")
    func testTransactionCommit() async throws {
        let email = try EmailAddress("commit@example.com")

        let identityId = try await database.withTransaction { db in
            let identity = try await TestFixtures.createTestIdentity(
                email: email,
                db: db
            )
            return identity.id
        }

        // Verify committed
        let found = try await database.read { db in
            try await Identity.Record
                .where { $0.id.eq(identityId) }
                .fetchOne(db)
        }

        let identity = try #require(found)
        #expect(identity.email == email)
    }

    @Test("Savepoint rollback")
    func testSavepointRollback() async throws {
        try await database.withTransaction { db in
            let identity1 = try await TestFixtures.createTestIdentity(
                email: try EmailAddress("outer@example.com"),
                db: db
            )

            do {
                try await db.withSavepoint(nil) { db in
                    _ = try await TestFixtures.createTestIdentity(
                        email: try EmailAddress("inner@example.com"),
                        db: db
                    )
                    throw TestError.intentionalRollback
                }
            } catch TestError.intentionalRollback {
                // Expected - inner rolled back
            }

            // Verify outer transaction still intact
            let found = try await Identity.Record
                .where { $0.id.eq(identity1.id) }
                .fetchOne(db)

            #expect(found != nil)
        }
    }
}
```

## 7. Add Query Validation with assertQuery Helper

### Current Issues:
- No validation of generated SQL
- No validation of query results format
- Hard to catch query regressions

### Improvement:
**New utility file: `Tests/Identity Backend Tests/Utilities/AssertQuery.swift`**

```swift
import Dependencies
import Foundation
import Records
import Testing

/// Assert that a query produces expected SQL and results
///
/// Pattern from swift-records for end-to-end query validation
@MainActor
func assertQuery<T>(
    _ query: T,
    sql expectedSQL: () -> String,
    results expectedResults: () -> String,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
) async where T: Sendable {
    @Dependency(\.defaultDatabase) var database

    // TODO: Implement SQL extraction and comparison
    // TODO: Implement result formatting and comparison
    // This is a placeholder for the full implementation
    // See swift-records/Tests/RecordsTests/Utilities/AssertQuery.swift
}
```

**Usage example:**
```swift
@Test("Query generates correct SQL")
func testQuerySQL() async {
    await assertQuery(
        Identity.Record
            .where { $0.email.eq(try! EmailAddress("test@example.com")) }
            .asSelect(),
        sql: {
            """
            SELECT * FROM "identities"
            WHERE "email" = $1
            """
        },
        results: {
            """
            ┌────┬──────────────────────┬──────┐
            │ id │ email                │ ...  │
            └────┴──────────────────────┴──────┘
            """
        }
    )
}
```

## 8. Improve Test Data Isolation

### Current Issues:
- All tests use same `TestFixtures.testEmail`
- Tests can conflict if run in parallel
- Hard to identify which test created which data

### Improvement:
**Pattern from swift-records:**
```swift
extension TestFixtures {
    /// Generate unique email for test isolation
    static func uniqueEmail(prefix: String = "test") -> EmailAddress {
        let uuid = UUID().uuidString.prefix(8)
        return try! EmailAddress("\(prefix)-\(uuid)@example.com")
    }

    /// Generate unique test identity
    static func createUniqueTestIdentity(
        emailPrefix: String = "test",
        password: String = testPassword,
        verified: Bool = true,
        db: any Database.Connection.`Protocol`
    ) async throws -> Identity.Record {
        try await createTestIdentity(
            email: uniqueEmail(prefix: emailPrefix),
            password: password,
            verified: verified,
            db: db
        )
    }
}
```

**Usage:**
```swift
@Test("Create identity with unique email")
func testCreateIdentity() async throws {
    let identity = try await database.write { db in
        try await TestFixtures.createUniqueTestIdentity(
            emailPrefix: "create",
            db: db
        )
    }

    #expect(!identity.passwordHash.isEmpty)
}
```

## 9. Add Concurrency Testing (Optional)

### Pattern from swift-records:
**New test file: `Tests/Identity Backend Tests/Integration/ConcurrencyTests.swift`**

```swift
@Suite(
    "Concurrency Tests",
    .disabled(),  // Enable for specific testing
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
    }
)
struct ConcurrencyTests {
    @Dependency(\.defaultDatabase) var database

    @Test("Concurrent identity creation")
    func testConcurrentCreation() async throws {
        let count = 50

        try await withThrowingTaskGroup(of: Identity.Record.self) { group in
            for i in 1...count {
                group.addTask {
                    try await database.write { db in
                        try await TestFixtures.createTestIdentity(
                            email: try EmailAddress("concurrent-\(i)@example.com"),
                            db: db
                        )
                    }
                }
            }

            var created = 0
            for try await _ in group {
                created += 1
            }

            #expect(created == count)
        }
    }

    @Test("Concurrent reads during write")
    func testConcurrentReads() async throws {
        // Create test data first
        let identity = try await database.write { db in
            try await TestFixtures.createTestIdentity(
                email: try EmailAddress("concurrent-read@example.com"),
                db: db
            )
        }

        // Perform concurrent reads
        try await withThrowingTaskGroup(of: Identity.Record?.self) { group in
            for _ in 1...10 {
                group.addTask {
                    try await database.read { db in
                        try await Identity.Record
                            .where { $0.id.eq(identity.id) }
                            .fetchOne(db)
                    }
                }
            }

            for try await result in group {
                #expect(result != nil)
            }
        }
    }
}
```

## 10. Better Test Names and Documentation

### Current Issues:
- Some test names could be more descriptive
- Missing comments explaining test intent

### Improvements:
**Pattern from swift-records:**
```swift
// ❌ Less clear
@Test("Create identity with password")

// ✅ More descriptive
@Test("INSERT identity with password returns complete record")

// ❌ Generic
@Test("Verify password for existing identity")

// ✅ Specific
@Test("Bcrypt.verify succeeds with correct password")

// ❌ Vague
@Test("Update last login timestamp")

// ✅ Clear intent
@Test("UPDATE lastLoginAt timestamp persists to database")
```

## Implementation Priority

### Phase 1: Critical Improvements (Do First)
1. ✅ Remove debug `do-catch` wrapper (lines 25-42)
2. ✅ Replace force unwraps with `#require()`
3. ✅ Add unique email generation for test isolation
4. ✅ Improve test names

### Phase 2: Testing Coverage (Next)
5. ⬜ Add constraint violation tests
6. ⬜ Add transaction and rollback tests
7. ⬜ Add error handling tests
8. ⬜ Add cleanup patterns

### Phase 3: Organization (Then)
9. ⬜ Reorganize into subdirectories
10. ⬜ Split AuthenticationTests into focused files
11. ⬜ Create MFA tests
12. ⬜ Create email verification tests

### Phase 4: Advanced (Later)
13. ⬜ Implement `assertQuery()` helper
14. ⬜ Add concurrency tests (optional, disabled by default)
15. ⬜ Add snapshot testing for queries

## Summary

Our tests are already using many good patterns from swift-records:
- ✅ Swift Testing framework
- ✅ Dependency injection
- ✅ Schema isolation
- ✅ Suite configuration
- ✅ Test fixtures

Key improvements needed:
1. Remove debug code
2. Use `#require()` instead of force unwraps
3. Add error and constraint testing
4. Add transaction testing
5. Improve test data isolation
6. Better organization and naming

These improvements will make our tests more robust, maintainable, and exemplary for future test development.
