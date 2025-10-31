//
//  Identity.Consumer.View.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import Dependencies
import IdentitiesTypes
import Identity_Frontend
import ServerFoundationVapor
import Vapor

extension Identity.View {
  /// Handles view requests for Consumer deployments.
  /// Delegates to domain-specific response handlers.
  public static func consumerResponse(
    view: Identity.View
  ) async throws -> any AsyncResponseEncodable {

    @Dependency(Identity.Consumer.Configuration.self) var config
    @Dependency(\.identity) var identity
    let configuration = config.consumer

    // Check authentication requirements
    try await Identity.Consumer.View.protect(
      view: view,
      with: Identity.Token.Access.self
    )

    // Delegate to domain-specific handlers
    switch view {
    case .create(let create):
      return try await Identity.Creation.response(view: create)

    case .authenticate(let authenticate):
      return try await Identity.Authentication.response(view: authenticate)

    case .delete:
      return try await Identity.Deletion.response()

    case .email(let email):
      return try await Identity.Email.response(view: email)

    case .password(let password):
      return try await Identity.Password.response(view: password)

    case .mfa(let mfa):
      // MFA views need to be handled via Frontend
      throw Abort(.notImplemented, reason: "MFA views not yet implemented in Consumer")

    case .logout:
      // Convert Consumer redirect to Frontend redirect
      let frontendRedirect = Identity.Frontend.Configuration.Redirect(
        loginSuccess: { _ in configuration.redirect.loginSuccess() },
        loginProtected: { configuration.redirect.loginProtected() },
        createProtected: { configuration.redirect.createProtected() },
        createVerificationSuccess: { configuration.redirect.createVerificationSuccess() },
        logoutSuccess: { configuration.redirect.logoutSuccess() }
      )
      return try await Identity.Logout.response(
        client: identity.logout.client,
        redirect: frontendRedirect
      )

    case .oauth(let oauth):
      return try await Identity.OAuth.response(view: oauth)
    }
  }
}
