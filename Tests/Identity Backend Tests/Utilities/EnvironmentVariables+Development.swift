import Foundation
import ServerFoundation

extension EnvironmentVariables {
  /// Development environment configuration that loads from .env.development file
  static var development: Self {
    var dictionary: [String: String] = [:]

    // Try to load from .env.development file
    let devEnvPath = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // Remove filename
      .deletingLastPathComponent()  // Remove "Utilities"
      .deletingLastPathComponent()  // Remove "Identity Backend Tests"
      .deletingLastPathComponent()  // Remove "Tests"
      .appendingPathComponent(".env.development")

    if let contents = try? String(contentsOf: devEnvPath, encoding: .utf8) {
      let lines = contents.components(separatedBy: .newlines)
      for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Skip comments and empty lines
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

        // Parse KEY=VALUE
        if let separatorIndex = trimmed.firstIndex(of: "=") {
          let key = String(trimmed[..<separatorIndex])
          let value = String(trimmed[trimmed.index(after: separatorIndex)...])
          dictionary[key] = value
          // Also set in process environment for Records to find
          setenv(key, value, 1)
        }
      }
    }

    return try! Self(dictionary: dictionary, requiredKeys: [])
  }
}
