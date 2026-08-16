//
//  Parity Support.swift
//  swift-authentication
//
//  Batch-0 wire-shape parity corpus support (url-routing-stack migration).
//  Pattern: swift-stripe-types Tests/Stripe Router Parity Tests/Parity Support.swift.
//

import Foundation
import IdentitiesTypes
import Testing
/// Compares a corpus against its canonical Swift entry.
func assertParity(
    _ corpus: String,
    fixture name: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    Corpus.compare(
        normalizeJSONBodies(corpus),
        named: name,
        sourceLocation: sourceLocation
    )
}

/// JSON bodies print with unordered keys (the `.json` body conversion does not
/// sort keys), so raw `body(utf8): {…}` lines flap between runs. Normalize by
/// re-serializing JSON-object bodies with `.sortedKeys`, marking the line
/// `body(utf8/sorted-keys):` as Batch-0 evidence of the normalization.
func normalizeJSONBodies(_ corpus: String) -> String {
    corpus
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { line -> String in
            let prefix = "body(utf8): "
            guard line.hasPrefix(prefix) else { return String(line) }
            let payload = String(line.dropFirst(prefix.count))
            guard payload.first == "{",
                let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)),
                let sorted = try? JSONSerialization.data(
                    withJSONObject: object,
                    options: [.sortedKeys, .withoutEscapingSlashes]
                ),
                let text = String(data: sorted, encoding: .utf8)
            else { return String(line) }
            return "body(utf8/sorted-keys): \(text)"
        }
        .joined(separator: "\n")
}

/// Round-trip failures are captured, unfixed, as Batch-0 evidence. A clean
/// suite records nothing; a drift from the canonical Swift entry fails.
func recordNonRoundTrips(
    _ failures: [String],
    fixture name: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let expectedName = "KNOWN-NON-ROUNDTRIP-\(name)"
    if failures.isEmpty {
        if Corpus.expected[expectedName] != nil {
            Issue.record(
                "Round-trips now clean for \(name); stale KNOWN-NON-ROUNDTRIP entry",
                sourceLocation: sourceLocation
            )
        }
        return
    }
    Corpus.compare(
        failures.joined(separator: "\n") + "\n",
        named: expectedName,
        sourceLocation: sourceLocation
    )
}

// The checked-in Swift table is the canonical parity corpus. Keeping the
// expected bytes in the test target preserves exact comparisons without a
// second, non-Swift fixture tree beside the tests.
enum Corpus {
    static func compare(
        _ produced: String,
        named name: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let producedData = Foundation.Data(produced.utf8)
        guard let expectedData = expected[name] else {
            Issue.record(
                "Canonical corpus has no entry named \(name)",
                sourceLocation: sourceLocation
            )
            return
        }
        if expectedData != producedData {
            let expected = String(decoding: expectedData, as: UTF8.self)
            Issue.record(
                """
                Corpus mismatch for \(name)
                --- expected ---
                \(expected)
                --- actual ---
                \(produced)
                """,
                sourceLocation: sourceLocation
            )
        }
    }
}

/// Deterministic fixed values only — no Date()/UUID() anywhere in the corpus.
enum Fixed {
    static let email = "parity@example.com"
    static let newEmail = "parity-new@example.com"
    static let password = "correct horse battery staple"
    static let token = "fixed-token-0123456789abcdef"
    static let sessionToken = "fixed-session-token"
    static let reauthToken = "fixed-reauth-token"
    static let code = "123456"
    static let phoneNumber = "+31612345678"
    static let provider = "github"
    static let state = "fixed-state"
    static let baseURL = "https://identity.example.com"

    /// A structurally valid, fully deterministic JWT (unsigned).
    static var jwt: JWT {
        JWT(
            header: .init(alg: "HS256"),
            payload: .init(sub: "00000000-0000-0000-0000-000000000000:\(email)"),
            signature: Data()
        )
    }
}
