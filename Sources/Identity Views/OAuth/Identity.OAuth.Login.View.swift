//
//  Identity.OAuth.Login.View.swift
//  coenttb-identities
//
//  OAuth provider selection view
//

import Foundation
import HTML
import HTMLWebsite
import IdentitiesTypes
import Language

extension Identity.OAuth.Login {
  public struct View: HTML {
    let providers: [(provider: Identity.OAuth.Provider, url: URL)]
    let cancelHref: URL

    public init(
      providers: [(provider: Identity.OAuth.Provider, url: URL)],
      cancelHref: URL
    ) {
      self.providers = providers
      self.cancelHref = cancelHref
    }

    public var body: some HTML {
      PageModule(theme: .authenticationFlow) {
        VStack(alignment: .center) {
          // Title
          h2 {
            TranslatedString(
              dutch: "Inloggen met",
              english: "Sign in with"
            )
          }
          .fontWeight(.semiBold)
          .textAlign(.center)

          // Provider buttons
          VStack(alignment: .stretch) {
            HTMLForEach(providers) { (provider, url) in
              a(href: .url(url)) {
                HStack(alignment: .center) {
                  // Provider icon placeholder
                  providerIcon(for: provider.identifier)

                  // Provider name
                  span { "\(provider.displayName)" }
                    .font(.body(.regular))
                }
                .gap(.length(.small))
                .justifyContent(.center)
              }
              .class("oauth-provider-button")
              .display(.block)
              .padding(.medium)
              .border(width: .px(1), style: .solid, color: .gray300)
              .borderRadius(.medium)
              .background(.white)
              .color(.gray900)
              .textDecoration(TextDecoration.none)
              .transition("all 0.2s ease")
              .backgroundColor(.gray100, pseudo: .hover)
              .borderColor(.gray400, pseudo: .hover)
              .transform(.scale(1.02), pseudo: .hover)

            }
          }
          .gap(.length(.medium))
          .width(.percent(100))
          .maxWidth(.px(400))

          // Divider
          div {
            hr()
              .border(.none)
              .borderTop(.properties(.init(width: .px(1))))
              .borderTop(color: .gray300)
              .margin(vertical: .large)
          }

          // Cancel link
          a(href: .url(cancelHref)) {
            TranslatedString(
              dutch: "Terug",
              english: "Back"
            )
          }
          .color(.gray600)
          .textDecoration(TextDecoration.none)
          .textDecoration(.underline, pseudo: .hover)
        }
        .gap(.length(.large))
        .width(.percent(100))
        .maxWidth(.px(400))
        .margin(.auto)
      }
    }

    // Helper function for provider icons
    @HTMLBuilder
    private func providerIcon(for identifier: String) -> some HTML {
      HTMLEmpty()
      //            switch identifier.lowercased() {
      //            case "github":
      //                // GitHub icon SVG
      //                SVG(
      //                    xmlns: "http://www.w3.org/2000/svg",
      //                    width: 24,
      //                    height: 24,
      //                    viewBox: "0 0 24 24",
      //                    fill: "currentColor"
      //                ) {
      //                    path(d: "M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z")
      //                }
      //
      //            case "google":
      //                // Google icon placeholder
      //                div {
      //                    "G"
      //                }
      //                .fontSize(.rem(1.5))
      //                .fontWeight(.bold)
      //                .color(.init(red: 66, green: 133, blue: 244, alpha: 1))
      //
      //            case "apple":
      //                // Apple icon placeholder
      //                div {
      //                    ""
      //                }
      //                .fontSize(.rem(1.5))
      //
      //            default:
      //                // Generic OAuth icon
      //                div {
      //                    "🔐"
      //                }
      //                .fontSize(.rem(1.5))
      //            }
    }
  }
}

// Namespace for OAuth views
extension Identity.OAuth {
  public enum Login {}
}
