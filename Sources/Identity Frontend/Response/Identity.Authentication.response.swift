//
//  Identity.Authentication.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 22/08/2025.
//

import Dependencies
import HTML
import IdentitiesTypes
import Identity_Views
import Language
import ServerFoundationVapor

// MARK: - Response Dispatcher

extension Identity.Authentication {
  /// Dispatches authentication view requests to appropriate handlers.
  public static func response(
    view: Identity.Authentication.View
  ) async throws -> any AsyncResponseEncodable {
    @Dependency(Identity.Frontend.Configuration.self) var configuration
    @Dependency(\.identity.router) var router

    switch view {
    case .credentials:
      return try await Identity.Frontend.htmlDocument(for: .authenticate(.credentials)) {
        Identity.Authentication.Credentials.View(
          passwordResetHref: router.url(for: .password(.view(.reset(.request)))),
          accountCreateHref: router.url(for: .create(.view(.request))),
          loginFormAction: router.url(for: .authenticate(.api(.credentials(.init()))))
        )
      }
    }
  }
}
