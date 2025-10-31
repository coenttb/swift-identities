# Phase 3A: MFA Testing Strategy

**Status**: Ready to implement
**Priority**: High
**Estimated**: 15-20 comprehensive tests

## Strategy Overview

### Approach: Use Public MFA Client Interfaces

Instead of trying to access package-level `Draft` initializers, we'll test MFA functionality through the **public MFA client interfaces**, which is actually a better approach because:

1. ✅ Tests the actual API surface that applications use
2. ✅ Doesn't require making internal types public
3. ✅ Tests the complete flow including database operations
4. ✅ More realistic integration testing

### MFA Client Access

The MFA clients are available through:
- `Identity.MFA.TOTP.Client` - TOTP (Authenticator app) functionality
- `Identity.MFA.BackupCodes` - Backup code functionality (accessed via TOTP client)

Configuration needed:
```swift
let totpConfig = Identity.MFA.TOTP.Configuration(
    issuer: "TestApp",
    algorithm: .sha1,
    digits: 6,
    timeStep: 30,
    verificationWindow: 1,
    backupCodeCount: 10,
    backupCodeLength: 8
)

let totpClient = Identity.MFA.TOTP.Client.backend(configuration: totpConfig)
```

## Test Organization

### Directory Structure
```
Tests/Identity Backend Tests/Integration/
├── MFA/
│   ├── TOTP/
│   │   ├── TOTPSetupTests.swift           (5-6 tests)
│   │   ├── TOTPVerificationTests.swift    (4-5 tests)
│   │   └── TOTPManagementTests.swift      (3-4 tests)
│   └── BackupCodes/
│       ├── BackupCodeGenerationTests.swift (3-4 tests)
│       └── BackupCodeVerificationTests.swift (3-4 tests)
```

## Detailed Test Plan

### 1. TOTP Setup Tests (~6 tests)

**File**: `Tests/Identity Backend Tests/Integration/MFA/TOTP/TOTPSetupTests.swift`

```swift
@Suite(
    "TOTP Setup Tests",
    .dependencies {
        $0.envVars = .development
        $0.defaultDatabase = Database.TestDatabase.withIdentitySchema()
    }
)
struct TOTPSetupTests {
    @Dependency(\.defaultDatabase) var database

    @Test("TOTP setup generates secret and QR code URL")
    func testTOTPSetup() async throws {
        // 1. Create test identity
        // 2. Call totpClient.setup()
        // 3. Verify secret is generated (base32 format)
        // 4. Verify QR code URL format
        // 5. Verify manual entry key format
        // 6. Verify TOTP record created in database (unconfirmed)
    }

    @Test("TOTP confirmSetup with valid code confirms setup")
    func testConfirmSetupWithValidCode() async throws {
        // 1. Setup TOTP
        // 2. Generate valid code from secret
        // 3. Call totpClient.confirmSetup()
        // 4. Verify record is marked as confirmed
        // 5. Verify confirmedAt timestamp set
    }

    @Test("TOTP confirmSetup with invalid code throws error")
    func testConfirmSetupWithInvalidCode() async throws {
        // Test error handling
    }

    @Test("TOTP isEnabled returns true after confirmation")
    func testIsEnabledAfterConfirmation() async throws {
        // Test status check
    }

    @Test("TOTP isEnabled returns false before confirmation")
    func testIsEnabledBeforeConfirmation() async throws {
        // Test status check
    }

    @Test("TOTP re-setup resets confirmation status")
    func testReSetup() async throws {
        // Test UPSERT behavior
    }
}
```

### 2. TOTP Verification Tests (~5 tests)

**File**: `Tests/Identity Backend Tests/Integration/MFA/TOTP/TOTPVerificationTests.swift`

```swift
@Test("TOTP verifyCode with valid code returns true")
func testVerifyValidCode() async throws {
    // 1. Setup and confirm TOTP
    // 2. Generate current valid code
    // 3. Verify code succeeds
    // 4. Check lastUsedAt updated
    // 5. Check usageCount incremented
}

@Test("TOTP verifyCode with invalid code returns false")
func testVerifyInvalidCode() async throws {
    // Test error handling
}

@Test("TOTP verifyCode before confirmation throws error")
func testVerifyBeforeConfirmation() async throws {
    // Test state validation
}

@Test("TOTP verifyCode updates usage statistics")
func testVerificationUpdatesStats() async throws {
    // Test side effects
}

@Test("TOTP verifyCode with debug bypass code succeeds")
func testDebugBypassCode() async throws {
    // Test development/testing bypass
}
```

### 3. TOTP Management Tests (~4 tests)

**File**: `Tests/Identity Backend Tests/Integration/MFA/TOTP/TOTPManagementTests.swift`

```swift
@Test("TOTP getStatus returns correct status data")
func testGetStatus() async throws {
    // Test status query
}

@Test("TOTP disable removes TOTP and backup codes")
func testDisable() async throws {
    // 1. Setup TOTP
    // 2. Generate backup codes
    // 3. Call disable()
    // 4. Verify TOTP record deleted
    // 5. Verify backup codes deleted
    // 6. Verify isEnabled returns false
}

@Test("TOTP generateQRCodeURL creates valid otpauth URL")
func testGenerateQRCodeURL() async throws {
    // Test URL generation
}

@Test("Multiple identities can have separate TOTP setups")
func testMultipleIdentities() async throws {
    // Test isolation
}
```

### 4. Backup Code Generation Tests (~4 tests)

**File**: `Tests/Identity Backend Tests/Integration/MFA/BackupCodes/BackupCodeGenerationTests.swift`

```swift
@Test("generateBackupCodes creates correct number of codes")
func testGenerateBackupCodes() async throws {
    // 1. Create identity with TOTP
    // 2. Generate backup codes
    // 3. Verify count matches configuration
    // 4. Verify all codes are unique
    // 5. Verify codes are correct length
    // 6. Verify codes saved to database (hashed)
}

@Test("generateBackupCodes replaces existing codes")
func testRegenerateBackupCodes() async throws {
    // 1. Generate codes
    // 2. Regenerate codes
    // 3. Verify old codes deleted
    // 4. Verify new codes work
}

@Test("remainingBackupCodes returns correct count")
func testRemainingBackupCodes() async throws {
    // Test count query
}

@Test("Backup codes are properly hashed in database")
func testBackupCodesHashed() async throws {
    // Verify security: codes not stored in plain text
}
```

### 5. Backup Code Verification Tests (~4 tests)

**File**: `Tests/Identity Backend Tests/Integration/MFA/BackupCodes/BackupCodeVerificationTests.swift`

```swift
@Test("verifyBackupCode with valid code returns true and marks used")
func testVerifyValidBackupCode() async throws {
    // 1. Generate backup codes
    // 2. Use one code
    // 3. Verify returns true
    // 4. Verify code marked as used
    // 5. Verify usedAt timestamp set
    // 6. Verify code cannot be reused
}

@Test("verifyBackupCode with invalid code returns false")
func testVerifyInvalidBackupCode() async throws {
    // Test error handling
}

@Test("verifyBackupCode with used code returns false")
func testVerifyUsedBackupCode() async throws {
    // Test idempotency
}

@Test("verifyBackupCode is atomic - concurrent usage safe")
func testConcurrentBackupCodeUsage() async throws {
    // Test race condition handling
}
```

## Test Fixtures Enhancement

Add to `TestFixtures.swift`:

```swift
// MARK: - MFA Test Fixtures

extension TestFixtures {
    /// Default TOTP configuration for tests
    static let defaultTOTPConfig = Identity.MFA.TOTP.Configuration(
        issuer: "TestApp",
        algorithm: .sha1,
        digits: 6,
        timeStep: 30,
        verificationWindow: 1,
        backupCodeCount: 10,
        backupCodeLength: 8
    )

    /// Creates a test identity with TOTP setup (unconfirmed)
    static func createIdentityWithTOTP(
        emailPrefix: String = "totp",
        db: any Database.Connection.`Protocol`
    ) async throws -> (identity: Identity.Record, setup: Identity.MFA.TOTP.Client.SetupData) {
        let identity = try await createUniqueTestIdentity(
            emailPrefix: emailPrefix,
            db: db
        )

        // Use the TOTP client to setup
        let totpClient = Identity.MFA.TOTP.Client.backend(configuration: defaultTOTPConfig)

        // Generate setup data
        let setupData = try await totpClient.generateSecret()

        // Note: Actual setup() method requires authentication, so we'll need
        // to use the internal Draft init or make it public for testing

        return (identity, setupData)
    }

    /// Generates a valid TOTP code for testing
    static func generateValidTOTPCode(secret: String) throws -> String {
        let totp = try TOTP(
            base32Secret: secret,
            timeStep: 30,
            digits: 6,
            algorithm: .sha1
        )
        return totp.currentCode()
    }
}
```

## Dependencies Needed

The MFA tests will need these additional imports:

```swift
import TOTP              // For TOTP code generation in tests
import RFC_6238          // For TOTP algorithm types
import Crypto            // For hashing verification
import OneTimePasswordShared  // For utilities
```

## Challenges and Solutions

### Challenge 1: Authentication Requirement

**Problem**: Some MFA client methods require authenticated identity (e.g., `setup()` uses `Identity.Record.get(by: .auth)`)

**Solution**:
- Use the lower-level client methods that accept identityId directly:
  - `generateSecret()` - no auth required
  - `confirmSetup(identityId:secret:code:)` - pass identityId
  - `verifyCode(identityId:code:)` - pass identityId

### Challenge 2: Draft Initializer Access

**Problem**: `Identity.MFA.TOTP.Record.Draft` and `Identity.MFA.BackupCodes.Record.Draft` have package-level initializers

**Solution**:
- **Option A** (Recommended): Use the MFA client methods which handle Draft creation internally
- **Option B**: Make Draft initializers public for testing
- **Option C**: Create test-specific factory methods that mirror the client logic

**Recommendation**: Use Option A - test through public interfaces

### Challenge 3: Secret Encryption

**Problem**: TOTP secrets are encrypted in database using `Identity.MFA.TOTP.Record.encryptSecret()`

**Solution**:
- Use the client methods which handle encryption/decryption
- Tests verify encrypted values exist in DB
- Tests verify decryption works via verification

## Implementation Steps

1. ✅ **Create test directory structure**
   ```bash
   mkdir -p "Tests/Identity Backend Tests/Integration/MFA/TOTP"
   mkdir -p "Tests/Identity Backend Tests/Integration/MFA/BackupCodes"
   ```

2. ✅ **Add TOTP dependency to test target** in Package.swift

3. ✅ **Create TOTPSetupTests.swift** with 6 tests

4. ✅ **Create TOTPVerificationTests.swift** with 5 tests

5. ✅ **Create TOTPManagementTests.swift** with 4 tests

6. ✅ **Create BackupCodeGenerationTests.swift** with 4 tests

7. ✅ **Create BackupCodeVerificationTests.swift** with 4 tests

8. ✅ **Run tests and verify** all passing

## Expected Test Count After Phase 3A

- Current: 56 tests
- New MFA tests: ~23 tests
- **Total: ~79 tests**

## Benefits of This Approach

1. ✅ **Tests real functionality** - Uses actual client interfaces
2. ✅ **No internal exposure** - Doesn't require making package types public
3. ✅ **Integration testing** - Tests complete flows including DB operations
4. ✅ **Maintainable** - Tests break if public API changes (good!)
5. ✅ **Realistic** - Mirrors how applications would use MFA

## Next Steps After Phase 3A

Once MFA testing is complete, proceed to:

- **Phase 3B**: Email Verification Testing (12-15 tests)
- **Phase 3C**: Password Reset Testing (10-12 tests)
- **Phase 3D**: OAuth Testing (8-10 tests)

**Total estimated after all Phase 3**: ~110-120 comprehensive tests

## Conclusion

Phase 3A is ready to implement using the public MFA client interfaces. This approach is:
- ✅ Cleaner than exposing internal types
- ✅ More realistic integration testing
- ✅ Tests the actual API surface
- ✅ Requires no changes to production code

**Status**: READY TO IMPLEMENT 🚀
