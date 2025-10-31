//
//  Identity.OAuth.Error.View.swift
//  coenttb-identities
//
//  OAuth error display view
//

import Foundation
import HTML
import HTMLWebsite
import IdentitiesTypes
import Language

extension Identity.OAuth.Error {
  public struct View: HTML {
    let errorMessage: String
    let retryHref: URL
    let cancelHref: URL

    public init(
      errorMessage: String,
      retryHref: URL,
      cancelHref: URL
    ) {
      self.errorMessage = errorMessage
      self.retryHref = retryHref
      self.cancelHref = cancelHref
    }

    public var body: some HTML {
      PageModule(theme: .content) {
        VStack(alignment: .center) {
          // Error icon
          div {
            "⚠️"
          }
          .fontSize(.rem(3))
          .marginBottom(.length(.medium))

          // Title
          h2 {
            TranslatedString(
              dutch: "OAuth Fout",
              english: "OAuth Error"
            )
          }
          //                    .font(.title(.regular))
          .fontSize(.large)
          .color(.red600)
          .marginBottom(.length(.medium))

          // Error message
          div {
            p {
              TranslatedString(
                dutch: "Er is een fout opgetreden tijdens het inloggen:",
                english: "An error occurred during authentication:"
              )
            }
            .marginBottom(.length(.small))

            div {
              code { errorMessage }
                .padding(.medium)
                .backgroundColor(.background.secondary)
                .borderRadius(.small)
                .display(.block)
                .wordBreak(.breakAll)
                .fontFamily(.monospace)
                .fontSize(.rem(0.9))
            }
          }
          .marginBottom(.length(.large))

          // Actions
          HStack(alignment: .center) {
            a(href: .url(retryHref)) {
              TranslatedString(
                dutch: "Opnieuw proberen",
                english: "Try Again"
              )
            }
            .class("btn btn-primary")
            .padding(vertical: .medium, horizontal: .large)
            .backgroundColor(.blue500)
            .color(.white)
            .borderRadius(.medium)
            .textDecoration(TextDecoration.none)
            .display(.inlineBlock)
            .backgroundColor(.blue600, pseudo: .hover)

            a(href: .url(cancelHref)) {
              TranslatedString(
                dutch: "Annuleren",
                english: "Cancel"
              )
            }
            .class("btn btn-secondary")
            .padding(vertical: .medium, horizontal: .large)
            .backgroundColor(.gray200)
            .color(.gray700)
            .borderRadius(.medium)
            .textDecoration(TextDecoration.none)
            .display(.inlineBlock)
            .backgroundColor(.gray300, pseudo: .hover)
          }
          .gap(.length(.medium))
          .justifyContent(.center)

          // Help text
          div {
            p {
              TranslatedString(
                dutch: "Als dit probleem aanhoudt, neem dan contact op met de beheerder.",
                english: "If this problem persists, please contact the administrator."
              )
            }
            .fontSize(.rem(0.9))
            .color(.gray600)
            .textAlign(.center)
          }
          .marginTop(.extraLarge)
        }
        .width(.percent(100))
        .maxWidth(.px(500))
        .margin(.auto)
        .padding(.extraLarge)
      }
      .maxWidth(.px(800))
      .margin(.auto)
    }
  }
}

// Namespace
extension Identity.OAuth {
  public enum Error {}
}
