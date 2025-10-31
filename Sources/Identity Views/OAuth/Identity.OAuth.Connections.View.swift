//
//  Identity.OAuth.Connections.View.swift
//  coenttb-identities
//
//  OAuth connections management view
//

import Foundation
import HTML
import HTMLWebsite
import IdentitiesTypes
import Language
import PointFreeHTMLTranslating

extension Identity.OAuth.Connections {
  public struct View: HTML {
    let connections: [Identity.OAuth.Connection]
    let availableProviders: [Identity.OAuth.Provider]
    let connectAction: (String) -> URL
    let disconnectAction: (String) -> URL
    let dashboardHref: URL

    public init(
      connections: [Identity.OAuth.Connection],
      availableProviders: [Identity.OAuth.Provider],
      connectAction: @escaping (String) -> URL,
      disconnectAction: @escaping (String) -> URL,
      dashboardHref: URL
    ) {
      self.connections = connections
      self.availableProviders = availableProviders
      self.connectAction = connectAction
      self.disconnectAction = disconnectAction
      self.dashboardHref = dashboardHref
    }

    public var body: some HTML {
      PageModule(theme: .content) {
        VStack(alignment: .stretch) {
          // Title
          Header(2) {
            TranslatedString(
              dutch: "OAuth Verbindingen",
              english: "OAuth Connections"
            )
          }
          .marginBottom(.large)

          // Connected accounts section
          if !connections.isEmpty {
            div {
              h3 {
                TranslatedString(
                  dutch: "Verbonden accounts",
                  english: "Connected accounts"
                )
              }
              .fontWeight(.semiBold)
              .marginBottom(.medium)

              VStack(alignment: .stretch) {
                HTMLForEach(connections) { connection in
                  connectionCard(for: connection)
                }
              }
              .gap(.length(.medium))
            }
            .marginBottom(.extraLarge)
          }

          // Available providers section
          if !availableProviders.isEmpty {
            div {
              h3 {
                TranslatedString(
                  dutch: "Beschikbare providers",
                  english: "Available providers"
                )
              }
              .fontWeight(.semiBold)
              .marginBottom(.medium)

              VStack(alignment: .stretch) {
                HTMLForEach(availableProviders) { provider in
                  availableProviderCard(for: provider)
                }
              }
              .gap(.length(.medium))
            }
          }

          // Empty state
          if connections.isEmpty && availableProviders.isEmpty {
            div {
              p {
                TranslatedString(
                  dutch: "Geen OAuth providers geconfigureerd.",
                  english: "No OAuth providers configured."
                )
              }
              .color(.gray600)
              .textAlign(.center)
              .padding(vertical: .extraLarge, horizontal: nil)
            }
          }

          // Back to dashboard link
          div {
            a(href: .url(dashboardHref)) {
              TranslatedString(
                dutch: "← Terug naar dashboard",
                english: "← Back to dashboard"
              )
            }
            .color(.gray600)
            .textDecoration(TextDecoration.none)
            .textDecoration(.underline, pseudo: .hover)
          }
          .marginTop(.extraLarge)
        }
        .width(.percent(100))
        .maxWidth(.px(600))
        .margin(.auto)
      }
      .maxWidth(.px(800))
      .margin(.auto)
    }

    @HTMLBuilder
    private func connectionCard(for connection: Identity.OAuth.Connection) -> some HTML {
      div {
        HStack(alignment: .center) {
          // Provider info
          VStack(alignment: .leading) {
            div {
              strong { connection.provider }
                .fontSize(.rem(1.1))
            }

            small {
              HTMLGroup {
                TranslatedString(
                  dutch: "Verbonden op: ",
                  english: "Connected: "
                )
              }
              span { formatDate(connection.connectedAt) }
            }
            .color(.gray600)
          }
          .flex(.custom(grow: 1, shrink: 1, basis: .auto))

          // Disconnect button
          form(
            action: .init(disconnectAction(connection.provider).absoluteString),
            method: .post
          ) {
            button(type: .submit) {
              TranslatedString(
                dutch: "Verbinding verbreken",
                english: "Disconnect"
              )
            }
            .class("btn btn-danger btn-sm")
            .padding(vertical: .small, horizontal: .medium)
            .borderRadius(.small)
            .backgroundColor(.red500)
            .color(.white)
            .border(.none)
            .cursor(.pointer)
            .backgroundColor(.red600, pseudo: .hover)
          }
        }
        .gap(.length(.medium))
      }
      .padding(.medium)

      //            .border(.width(.px(1)))
      //            .border(.color(.gray300))
      //            .border(.radius(.medium))
      .background(.white)
    }

    @HTMLBuilder
    private func availableProviderCard(for provider: Identity.OAuth.Provider) -> some HTML {
      div {
        HStack(alignment: .center) {
          // Provider info
          VStack(alignment: .leading) {
            div {
              strong { provider.displayName }
                .fontSize(.rem(1.1))
            }

            small {
              TranslatedString(
                dutch: "Niet verbonden",
                english: "Not connected"
              )
            }
            .color(.gray600)
          }
          .flex(.custom(grow: 1, shrink: 1, basis: .auto))

          // Connect button
          a(href: .url(connectAction(provider.identifier))) {
            TranslatedString(
              dutch: "Verbinden",
              english: "Connect"
            )
          }
          .class("btn btn-primary btn-sm")
          .padding(vertical: .medium, horizontal: .small)
          .borderRadius(.small)
          .backgroundColor(.blue)
          .color(.white)
          .textDecoration(TextDecoration.none)
          .display(.inlineBlock)
          .opacity(0.9, pseudo: .hover)
        }
        .gap(.length(.medium))
      }
      .padding(.medium)
      .borderWidth(.px(1))
      .borderColor(.gray300)
      .borderRadius(.medium)
      .backgroundColor(.gray100)
    }

    private func formatDate(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      return formatter.string(from: date)
    }
  }
}

// Namespace
extension Identity.OAuth {
  public enum Connections {}
}
