//
//  Identity.Password.Handlers.swift
//  coenttb-identities
//
//  Feature-based handlers for Password functionality
//

import Dependencies
import HTML
import IdentitiesTypes
import Identity_Views
import Language
import ServerFoundationVapor

// MARK: - Response Dispatcher

extension Identity.Password {
  /// Dispatches password view requests to appropriate handlers.
  public static func response(
    view: Identity.Password.View,

  ) async throws -> any AsyncResponseEncodable {
    @Dependency(Identity.Frontend.Configuration.self) var configuration
    @Dependency(\.identity.router) var router

    switch view {
    case .reset(let reset):
      switch reset {
      case .request:
        @Dependency(Identity.Frontend.Configuration.self) var configuration

        return try await Identity.Frontend.htmlDocument(
          for: .password(.reset(.request))
        ) {
          Identity.Password.Reset.Request.View(
            formActionURL: router.url(for: .password(.api(.reset(.request(.init()))))),
            homeHref: configuration.navigation.home
          )
        }
      case .confirm:
        return try await handleResetConfirm()
      }

    case .change(let change):
      switch change {
      case .request:
        return try await handleChangeRequest()
      }
    }
  }
}

extension Identity.Password {

  /// Handles password reset confirmation view.
  public static func handleResetConfirm(

    ) async throws -> any AsyncResponseEncodable
  {
    @Dependency(Identity.Frontend.Configuration.self) var configuration

    @Dependency(\.request) var req

    let token = req?.parameters.get("token") ?? ""
    @Dependency(\.identity.router) var router

    return try await Identity.Frontend.htmlDocument(
      for: .password(.reset(.confirm(.init())))
    ) {
      PageModule(theme: .authenticationFlow) {
        VStack {
          TranslatedString(
            dutch: "Stel een nieuw wachtwoord in",
            english: "Set a new password"
          )
          .font(.body(.regular))

          form(
            action: .init(router.url(for: .password(.api(.reset(.confirm(.init()))))).relativePath),
            method: .post
          ) {
            VStack {
              input.hidden(
                name: "token",
                value: .init("\(token)")
              )

              input.password(
                name: "newPassword",
                placeholder: "New Password",
                required: true
              )

              AnyHTML(
                Button.submit {
                  TranslatedString(
                    dutch: "Wachtwoord resetten",
                    english: "Reset Password"
                  )
                }
              )
            }
            .gap(.length(.medium))
          }
        }
        .gap(.length(.medium))
      }
      .width(.percent(100))
    }
  }

  /// Handles password change request view.
  public static func handleChangeRequest(

    ) async throws -> any AsyncResponseEncodable
  {
    @Dependency(Identity.Frontend.Configuration.self) var configuration
    @Dependency(\.identity.router) var router
    @Dependency(\.identity.require) var requireIdentity

    let email = try? await requireIdentity().email.rawValue

    return try await Identity.Frontend.htmlDocument(
      for: .password(.change(.request))
    ) {
      try await Identity.Password.Change.Request.View(
        currentUserName: email ?? "...",
        formActionURL: router.url(for: .password(.api(.change(.request(.init()))))),
        redirectOnSuccess: configuration.redirect.logoutSuccess()
      )
    }
  }
}
