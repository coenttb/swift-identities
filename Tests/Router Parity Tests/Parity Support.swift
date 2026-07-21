//
//  Parity Support.swift
//  swift-authentication
//
//  Batch-0 wire-shape parity corpus support (url-routing-stack migration).
//  Pattern: swift-stripe-types Tests/Router Parity Tests/Parity Support.swift.
//

import Foundation
import IdentitiesTypes
import Testing
import URL_Routing_Test_Support

/// Compares a corpus against `__Corpus__/<name>.txt`, recording on first run.
func assertParity(
    _ corpus: String,
    fixture name: String,
    filePath: String = #filePath
) throws {
    let url = URL(fileURLWithPath: filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("__Corpus__")
        .appendingPathComponent("\(name).txt")
    let outcome = try Parity.fixture(normalizeJSONBodies(corpus), at: url)
    if case .mismatched(let diff) = outcome {
        Issue.record("Parity mismatch for \(name):\n\(diff)")
    }
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

/// Round-trip failures are captured, unfixed, as Batch-0 evidence
/// (`__Corpus__/KNOWN-NON-ROUNDTRIP-<name>.txt`, record-when-absent). A clean
/// suite records nothing; a drift from the recorded set fails.
func recordNonRoundTrips(
    _ failures: [String],
    fixture name: String,
    filePath: String = #filePath
) throws {
    let url = URL(fileURLWithPath: filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("__Corpus__")
        .appendingPathComponent("KNOWN-NON-ROUNDTRIP-\(name).txt")
    let exists = FileManager.default.fileExists(atPath: url.path)
    if failures.isEmpty {
        if exists {
            Issue.record("Round-trips now clean for \(name); stale KNOWN-NON-ROUNDTRIP fixture")
        }
        return
    }
    let outcome = try Parity.fixture(failures.joined(separator: "\n") + "\n", at: url)
    if case .mismatched(let diff) = outcome {
        Issue.record("Known-non-round-trip drift for \(name):\n\(diff)")
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
