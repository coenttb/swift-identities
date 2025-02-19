//
//  File.swift
//  swift-web
//
//  Created by Coen ten Thije Boonkkamp on 17/10/2024.
//

/// Defines the reauthorization API type.
///
/// This typealias maps the API route's action name to its parameter type.
/// The codebase follows these naming patterns:
/// - Data structures use nouns (e.g., `Reauthorization`, `Credentials`)
/// - Client methods use a mix of verbs and capability nouns (e.g., `login`, `authenticate`)
/// - API routes generally use verbs or action nouns (e.g., `authenticate`, `logout`)
///
/// Example:
/// ```swift
/// // Parameter type (noun)
/// let reauth = Identity.Reauthorization(password: "current_password")
///
/// // API route (action)
/// .case(Identity.API.reauthorize)
/// ```
extension Identity.API {
   public typealias Reauthorize = Identity.Reauthorization
}
