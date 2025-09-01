import Testing
import Foundation
import Dependencies
import Identities
@testable import Identity_Shared
import TOTP
import OneTimePasswordShared

@Suite(
    "TOTP Debugging Tests",
    .dependency(\.date, .init { Date() })
)
struct TOTPDebuggingTests {
    
    @Test("Verify Date and Unix Timestamp")
    func verifyDateAndTimestamp() throws {
        // Check what Date() returns
        let now = Date()
        let timestamp = now.timeIntervalSince1970
        
        print("=== Date and Timestamp Debug ===")
        print("Current Date: \(now)")
        print("Unix Timestamp: \(timestamp)")
        print("TimeZone: \(TimeZone.current)")
        print("TimeZone abbreviation: \(TimeZone.current.abbreviation() ?? "none")")
        print("Seconds from GMT: \(TimeZone.current.secondsFromGMT(for: now))")
        
        // Calculate what the timestamp should be for a known date
        let knownDate = Date(timeIntervalSince1970: 1755775836) // From your logs
        print("\nKnown date (1755775836): \(knownDate)")
        print("Should be: 2025-08-21 11:30:36 UTC")
        
        // Check if dependency date matches regular Date
        @Dependency(\.date) var dependencyDate
        let depDate = dependencyDate()
        let depTimestamp = depDate.timeIntervalSince1970
        
        print("\nDependency Date: \(depDate)")
        print("Dependency Timestamp: \(depTimestamp)")
        print("Difference from Date(): \(depTimestamp - timestamp) seconds")
        
        #expect(abs(depTimestamp - timestamp) < 1.0, "Dependency date should match regular Date()")
    }
    
    @Test("Test TOTP with Known Secret and Timestamp")
    func testTOTPWithKnownValues() throws {
        // Use the exact secret and timestamp from your logs
        let secret = "KIWV65ISTT4U34ME"
        let testTimestamp: TimeInterval = 1755775836 // 2025-08-21 11:30:36 UTC
        let testDate = Date(timeIntervalSince1970: testTimestamp)
        
        print("=== TOTP Generation Test ===")
        print("Secret: \(secret)")
        print("Test Date: \(testDate)")
        print("Test Timestamp: \(testTimestamp)")
        
        // Create TOTP instance
        let totp = try TOTP(
            base32Secret: secret,
            timeStep: 30,
            digits: 6,
            algorithm: .sha1
        )
        
        // Generate code at the exact test time
        let code = totp.generate(at: testDate)
        print("Generated code at test time: \(code)")
        print("Your logs showed server generated: 338176")
        print("Authenticator apps showed: 415730")
        
        // Check what code would be generated at different time offsets
        print("\n=== Codes at different time offsets ===")
        for hoursOffset in [-2, -1, 0, 1, 2] {
            let offsetDate = testDate.addingTimeInterval(Double(hoursOffset * 3600))
            let offsetCode = totp.generate(at: offsetDate)
            let offsetTimestamp = offsetDate.timeIntervalSince1970
            print("\(hoursOffset) hours: \(offsetCode) (timestamp: \(offsetTimestamp))")
        }
        
        // Try to find where code 415730 might come from
        print("\n=== Searching for authenticator code 415730 ===")
        var found = false
        for dayOffset in -30...30 {
            for hourOffset in 0..<24 {
                let searchDate = testDate.addingTimeInterval(Double(dayOffset * 86400 + hourOffset * 3600))
                let searchCode = totp.generate(at: searchDate)
                if searchCode == "415730" {
                    print("FOUND! Code 415730 at: \(searchDate)")
                    print("That's \(dayOffset) days and \(hourOffset) hours from test time")
                    print("Timestamp: \(searchDate.timeIntervalSince1970)")
                    found = true
                    break
                }
            }
            if found { break }
        }
        
        if !found {
            print("Code 415730 not found in ±30 days range")
        }
    }
    
    @Test("Test Base32 Encoding/Decoding")
    func testBase32EncodingDecoding() throws {
        let secret = "KIWV65ISTT4U34ME"
        
        print("=== Base32 Encoding Test ===")
        print("Original secret: \(secret)")
        
        // Decode the secret
        guard let decodedData = Data(base32Encoded: secret) else {
            Issue.record("Failed to decode Base32 secret")
            return
        }
        
        print("Decoded bytes: \(decodedData.map { String(format: "%02x", $0) }.joined())")
        print("Decoded length: \(decodedData.count) bytes")
        
        // Re-encode and check if it matches
        let reencoded = decodedData.base32EncodedString()
        print("Re-encoded: \(reencoded)")
        
        // Remove padding for comparison
        let reencodedNoPadding = reencoded.replacingOccurrences(of: "=", with: "")
        print("Re-encoded (no padding): \(reencodedNoPadding)")
        
        #expect(reencodedNoPadding == secret, "Re-encoded secret should match original")
        
        // Test with variations
        print("\n=== Testing secret variations ===")
        let variations = [
            secret,
            secret + "====",  // With padding
            secret.lowercased(),
            "JBSWY3DPEHPK3PXP"  // Known test vector
        ]
        
        for variant in variations {
            if let variantData = Data(base32Encoded: variant) {
                let variantHex = variantData.map { String(format: "%02x", $0) }.joined()
                print("\(variant): \(variantHex)")
                
                // Generate TOTP for this variant
                if let variantTOTP = try? TOTP(base32Secret: variant) {
                    let variantCode = variantTOTP.generate(at: Date(timeIntervalSince1970: 1755775836))
                    print("  -> TOTP: \(variantCode)")
                }
            } else {
                print("\(variant): Failed to decode")
            }
        }
    }
    
    @Test("Compare TOTP Implementations")
    func compareTOTPImplementations() throws {
        let secret = "KIWV65ISTT4U34ME"
        let testDate = Date(timeIntervalSince1970: 1755775836)
        
        print("=== TOTP Implementation Comparison ===")
        
        // Test with our TOTP
        let totp = try TOTP(base32Secret: secret)
        let ourCode = totp.generate(at: testDate)
        print("Our implementation: \(ourCode)")
        
        // Test time step calculation
        let timeStep = Int(testDate.timeIntervalSince1970 / 30)
        print("Time step: \(timeStep)")
        print("Expected: 58525861 (from logs)")
        
        #expect(timeStep == 58525861, "Time step should match logs")
        
        // Test with different configurations
        print("\n=== Testing different TOTP parameters ===")
        
        // Standard config (what we use)
        let standardTOTP = try TOTP(base32Secret: secret, digits: 6, algorithm: .sha1)
        print("SHA1, 6 digits, 30s: \(standardTOTP.generate(at: testDate))")
        
        // Try SHA256
        let sha256TOTP = try TOTP(base32Secret: secret, digits: 6, algorithm: .sha256)
        print("SHA256, 6 digits, 30s: \(sha256TOTP.generate(at: testDate))")
        
        // Try 8 digits
        let eightDigitTOTP = try TOTP(base32Secret: secret, digits: 8, algorithm: .sha1)
        print("SHA1, 8 digits, 30s: \(eightDigitTOTP.generate(at: testDate))")
    }
    
    @Test("Test with Dependency Date")
    func testWithDependencyDate() throws {
        @Dependency(\.date) var date
        
        let secret = "KIWV65ISTT4U34ME"
        let totp = try TOTP(base32Secret: secret)
        
        print("=== Testing with Dependency Date ===")
        
        // Get current date from dependency
        let depDate = date()
        print("Dependency date: \(depDate)")
        print("Dependency timestamp: \(depDate.timeIntervalSince1970)")
        
        // Generate code using dependency date
        let codeWithDep = totp.generate(at: depDate)
        print("Code with dependency date: \(codeWithDep)")
        
        // Generate code using regular Date()
        let regularDate = Date()
        let codeWithRegular = totp.generate(at: regularDate)
        print("Code with regular Date(): \(codeWithRegular)")
        
        // They should be very close (within same 30-second window)
        if abs(depDate.timeIntervalSince(regularDate)) < 30 {
            #expect(codeWithDep == codeWithRegular, "Codes should match within same time window")
        }
        
        // Test what happens when we manipulate the dependency
        try withDependencies {
            // Set date to a fixed time (from your logs)
            $0.date = .init { Date(timeIntervalSince1970: 1755775836) }
        } operation: {
            @Dependency(\.date) var fixedDate
            let fixed = fixedDate()
            let fixedCode = totp.generate(at: fixed)
            print("\nWith fixed dependency date: \(fixed)")
            print("Fixed dependency code: \(fixedCode)")
            print("Should be: 338176 (from logs)")
        }
    }
    
    @Test("Timezone Impact on TOTP")
    func testTimezoneImpact() throws {
        let secret = "KIWV65ISTT4U34ME"
        let totp = try TOTP(base32Secret: secret)
        
        print("=== Timezone Impact Test ===")
        
        // Create a date
        let now = Date()
        let timestamp = now.timeIntervalSince1970
        
        print("Current date: \(now)")
        print("Current timestamp: \(timestamp)")
        print("Current timezone: \(TimeZone.current)")
        print("GMT offset: \(TimeZone.current.secondsFromGMT(for: now)) seconds")
        
        // Generate TOTP with current time
        let currentCode = totp.generate(at: now)
        print("TOTP at current time: \(currentCode)")
        
        // Simulate what would happen if timestamp included timezone offset
        let offsetTimestamp = timestamp + Double(TimeZone.current.secondsFromGMT(for: now))
        let offsetDate = Date(timeIntervalSince1970: offsetTimestamp)
        let offsetCode = totp.generate(at: offsetDate)
        print("\nIf timestamp included TZ offset:")
        print("Offset timestamp: \(offsetTimestamp)")
        print("Offset date: \(offsetDate)")
        print("TOTP with offset: \(offsetCode)")
        
        // Calculate how many time steps difference
        let timeStepDifference = Int(TimeZone.current.secondsFromGMT(for: now) / 30)
        print("Time steps difference: \(timeStepDifference)")
        
        // This would explain the mismatch if the server is somehow using offset timestamps
        if TimeZone.current.secondsFromGMT(for: now) == 7200 { // CEST is UTC+2
            print("\n⚠️ You're in CEST (UTC+2). If timestamps include this offset,")
            print("   TOTP codes would be 240 time steps (7200/30) ahead!")
        }
    }
}