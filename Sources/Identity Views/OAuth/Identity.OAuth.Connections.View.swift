//
//  Identity.OAuth.Connections.View.swift
//  coenttb-identities
//
//  OAuth connections management view
//

import Foundation
import HTML
import IdentitiesTypes
import Language
import Translating
import Webpage

extension Identity.OAuth.Connections {
    public struct View: HTML.View {
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

        public var body: some HTML.View {
            PageModule(theme: .content) {
                VStack(alignment: .stretch) {
                    // Title
                    Header(2) {
                        TranslatedString(
                            dutch: "OAuth Verbindingen",
                            english: "OAuth Connections"
                        )
                    }
                    .css
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
                            .css
                            .fontWeight(.semiBold)
                            .marginBottom(.medium)

                            VStack(alignment: .stretch) {
                                for connection in connections {
                                    ConnectionCard(
                                        connection: connection,
                                        disconnectHref: disconnectAction(connection.provider)
                                    )
                                }
                            }
                            .css
                            .gap(.length(.rem(1.5)))
                        }
                        .css
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
                            .css
                            .fontWeight(.semiBold)
                            .marginBottom(.medium)

                            VStack(alignment: .stretch) {
                                for provider in availableProviders {
                                    AvailableProviderCard(
                                        provider: provider,
                                        connectHref: connectAction(provider.identifier)
                                    )
                                }
                            }
                            .css
                            .gap(.length(.rem(1.5)))
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
                            .css
                            .color(.gray600)
                            .textAlign(.center)
                            .padding(vertical: .extraLarge, horizontal: nil)
                        }
                    }

                    // Back to dashboard link
                    div {
                        a(href: .init(dashboardHref.absoluteString)) {
                            TranslatedString(
                                dutch: "← Terug naar dashboard",
                                english: "← Back to dashboard"
                            )
                        }
                        .css
                        .color(.gray600)
                        .textDecoration(TextDecoration.none)
                        .hover { $0.textDecoration(.underline) }
                    }
                    .css
                    .marginTop(.extraLarge)
                }
                .css
                .width(.percent(100))
                .maxWidth(.px(600))
                .margin(.auto)
            }
            .css
            .maxWidth(.px(800))
            .margin(.auto)
        }

    }
}

// MARK: - Concrete list-item types
//
// `Render.Builder.buildArray(_:) -> [V]`
// (swift-render-primitives/Sources/Render Primitive/Render.Builder.swift:43) must reify a
// concrete element type `V`. These two were previously
// `@HTML.Builder private func …(for:) -> some HTML.View` helpers: an OPAQUE element type,
// which cannot be reified inside `buildArray` while the enclosing `body`'s own opaque type is
// still under inference — the compiler reports "underlying type for opaque result type … could
// not be inferred". `Render.Builder` vends no `buildExpression` and no `buildFinalResult`, so
// there is no hook to normalize the element: the loop body's raw type flows straight into
// `buildArray`.
//
// Naming them makes the element type concrete. This is exactly the shape of the module's
// already-green `for` loop (`BackupCodesGrid` / `BackupCodeItem`,
// Identity.View.MFA.BackupCodes.Display.swift:110-128). Opacity is fine as a `body` — these
// structs' own bodies are still `some HTML.View` and still carry the full `.css` chains. It is
// only fatal as a `buildArray` element type.
//
// The action closures are resolved to a `URL` at the call site, so these carry no dependency
// back on the parent view.

private struct ConnectionCard: HTML.View {
    let connection: Identity.OAuth.Connection
    let disconnectHref: URL

    var body: some HTML.View {
        div {
            HStack(alignment: .middle) {
                // Provider info
                // `.leading` is not an AlignItems value on the institute surface; the CSS
                // logical-start alignment it denoted is `.start`.
                VStack(alignment: .start) {
                    div {
                        strong { connection.provider }
                            .css
                            .fontSize(.rem(1.1))
                    }

                    small {
                        HTML.Group {
                            TranslatedString(
                                dutch: "Verbonden op: ",
                                english: "Connected: "
                            )
                        }
                        span { formatDate(connection.connectedAt) }
                    }
                    .css
                    .color(.gray600)
                }
                .css
                .flex(.custom(grow: 1, shrink: 1, basis: .auto))

                // Disconnect button
                form(
                    action: .init(disconnectHref.absoluteString),
                    method: .post
                ) {
                    button(type: .submit) {
                        TranslatedString(
                            dutch: "Verbinding verbreken",
                            english: "Disconnect"
                        )
                    }
                    .class("btn btn-danger btn-sm")
                    .css
                    .padding(vertical: .small, horizontal: .medium)
                    .borderRadius(.rem(0.375))
                    .backgroundColor(.red500)
                    .color(.white)
                    .border(.none)
                    .cursor(.pointer)
                    .hover { $0.backgroundColor(.red600) }
                }
            }
            .css
            .gap(.length(.rem(1.5)))
        }
        .css
        .padding(.medium)

        //            .border(.width(.px(1)))
        //            .border(.color(.gray300))
        //            .border(.radius(.medium))
        .backgroundColor(.white)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct AvailableProviderCard: HTML.View {
    let provider: Identity.OAuth.Provider
    let connectHref: URL

    var body: some HTML.View {
        div {
            HStack(alignment: .middle) {
                // Provider info
                VStack(alignment: .start) {
                    div {
                        strong { provider.displayName }
                            .css
                            .fontSize(.rem(1.1))
                    }

                    small {
                        TranslatedString(
                            dutch: "Niet verbonden",
                            english: "Not connected"
                        )
                    }
                    .css
                    .color(.gray600)
                }
                .css
                .flex(.custom(grow: 1, shrink: 1, basis: .auto))

                // Connect button
                a(href: .init(connectHref.absoluteString)) {
                    TranslatedString(
                        dutch: "Verbinden",
                        english: "Connect"
                    )
                }
                .class("btn btn-primary btn-sm")
                .css
                .padding(vertical: .medium, horizontal: .small)
                .borderRadius(.rem(0.375))
                .backgroundColor(.blue)
                .color(.white)
                .textDecoration(TextDecoration.none)
                .display(.inlineBlock)
                .hover { $0.opacity(0.9) }
            }
            .css
            .gap(.length(.rem(1.5)))
        }
        .css
        .padding(.medium)
        .borderWidth(.px(1))
        .borderColor(.gray300)
        .borderRadius(.rem(0.5))
        .backgroundColor(.gray100)
    }
}

// Namespace
extension Identity.OAuth {
    public enum Connections {}
}
