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

/// Compares a corpus against its Swift-embedded reference document.
func assertParity(
    _ corpus: String,
    fixture name: String
) throws {
    let actual = normalizeJSONBodies(corpus)
    guard let expected = Corpus[name] else {
        Issue.record(Comment(rawValue: "No embedded parity corpus named \(name)"))
        return
    }
    guard actual != expected else { return }
    let report = difference(expected: expected, actual: actual)
    Issue.record(Comment(rawValue: "Parity mismatch for \(name):\n\(report)"))
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
/// (the embedded `KNOWN-NON-ROUNDTRIP-<name>` document). A clean suite
/// expects no such document; a drift from the recorded set fails.
func recordNonRoundTrips(
    _ failures: [String],
    fixture name: String
) throws {
    let expected = Corpus["KNOWN-NON-ROUNDTRIP-\(name)"]
    if failures.isEmpty {
        if expected != nil {
            Issue.record(
                Comment(
                    rawValue: "Round-trips now clean for \(name); "
                        + "stale KNOWN-NON-ROUNDTRIP document"
                )
            )
        }
        return
    }
    let actual = failures.joined(separator: "\n") + "\n"
    guard let expected else {
        Issue.record(
            Comment(rawValue: "No embedded KNOWN-NON-ROUNDTRIP document for \(name)")
        )
        return
    }
    guard actual != expected else { return }
    let report = difference(expected: expected, actual: actual)
    Issue.record(Comment(rawValue: "Known-non-round-trip drift for \(name):\n\(report)"))
}

/// Renders the first differing lines of two corpora, for a readable failure.
private func difference(expected: String, actual: String) -> String {
    let expectedLines = expected.split(separator: "\n", omittingEmptySubsequences: false)
    let actualLines = actual.split(separator: "\n", omittingEmptySubsequences: false)
    var differences: [String] = []
    for index in 0..<max(expectedLines.count, actualLines.count) {
        let expected = index < expectedLines.count ? expectedLines[index] : "<absent>"
        let actual = index < actualLines.count ? actualLines[index] : "<absent>"
        if expected != actual {
            differences.append("line \(index + 1):\n  - \(expected)\n  + \(actual)")
        }
        if differences.count >= 40 {
            differences.append("… (further differences truncated)")
            break
        }
    }
    return differences.joined(separator: "\n")
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
