//
//  Identity.OAuth.Login.View.swift
//  coenttb-identities
//
//  OAuth provider selection view
//

import Foundation
import HTML
import IdentitiesTypes
import Language
import Translating
import Webpage

extension Identity.OAuth.Login {
    public struct View: HTML.View {
        let providers: [(provider: Identity.OAuth.Provider, url: URL)]
        let cancelHref: URL

        public init(
            providers: [(provider: Identity.OAuth.Provider, url: URL)],
            cancelHref: URL
        ) {
            self.providers = providers
            self.cancelHref = cancelHref
        }

        public var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack(alignment: .center) {
                    // Title
                    h2 {
                        TranslatedString(
                            dutch: "Inloggen met",
                            english: "Sign in with"
                        )
                    }
                    .css
                    .fontWeight(.semiBold)
                    .textAlign(.center)

                    // Provider buttons
                    VStack(alignment: .stretch) {
                        for (provider, url) in providers {
                            ProviderButton(provider: provider, url: url)
                        }
                    }
                    .css
                    .gap(.length(.rem(1.5)))
                    .width(.percent(100))
                    .maxWidth(.px(400))

                    // Divider
                    div {
                        hr()
                            .css
                            .border(.none)
                            // Was two chained calls, `.borderTop(.properties(.init(width: .px(1))))`
                            // then `.borderTop(color: .gray300)`. Merged into the single
                            // width/style/color overload the tower vends — the shape used by
                            // swift-webpage/Sources/Webpage/Card.swift:25.
                            .borderTop(width: .px(1), style: .solid, color: .gray300)
                            .margin(vertical: .large, horizontal: nil)
                    }

                    // Cancel link
                    a(href: .init(cancelHref.absoluteString)) {
                        TranslatedString(
                            dutch: "Terug",
                            english: "Back"
                        )
                    }
                    .css
                    .color(.gray600)
                    .textDecoration(TextDecoration.none)
                    .hover { $0.textDecoration(.underline) }
                }
                .css
                .gap(.length(.rem(3)))
                .width(.percent(100))
                .maxWidth(.px(400))
                .margin(.auto)
            }
        }

    }
}

// MARK: - Concrete list-item type
//
// `Render.Builder.buildArray(_:) -> [V]`
// (swift-render-primitives/Sources/Render Primitive/Render.Builder.swift:43) must reify a
// concrete element type `V`. The loop body here used to be the inline `a(href:) { … }.css.…`
// chain, whose type is OPAQUE — `a`/`div` are `callAsFunction`s returning `some HTML.View`
// (swift-html-render/Sources/HTML Elements Rendering/div Content Division.swift:12-14) and the
// `.css` chain returns `HTML.CSS<some HTML.View>`. An opaque element cannot be reified inside
// `buildArray` while the enclosing `body`'s own opaque type is still under inference.
//
// Naming it makes the element type concrete — the shape of the module's already-green loop
// (`BackupCodesGrid` / `BackupCodeItem`, Identity.View.MFA.BackupCodes.Display.swift:110-128).
//
// `providerIcon` stays `some HTML.View`: opacity is fine in ordinary `buildBlock` position, and
// is only fatal as a `buildArray` element type. Its commented-out icon `switch` is pre-existing
// (heritage) and is preserved verbatim.

private struct ProviderButton: HTML.View {
    let provider: Identity.OAuth.Provider
    let url: URL

    var body: some HTML.View {
        a(href: .init(url.absoluteString)) {
            HStack(alignment: .middle) {
                // Provider icon placeholder
                providerIcon(for: provider.identifier)

                // Provider name
                span { "\(provider.displayName)" }
                    .css
                    .font(.body(.regular))
            }
            .css
            .gap(.length(.rem(0.75)))
            .justifyContent(.center)
        }
        .class("oauth-provider-button")
        .css
        .display(.block)
        .padding(.medium)
        .border(width: .px(1), style: .solid, color: .gray300)
        .borderRadius(.rem(0.5))
        .backgroundColor(.white)
        .color(.gray900)
        .textDecoration(TextDecoration.none)
        .inlineStyle("transition", "all 0.2s ease")
        .hover {
            $0
                .backgroundColor(.gray100)
                .borderColor(.gray400)
                .inlineStyle("transform", "scale(1.02)")
        }
    }

    // Helper function for provider icons
    @HTML.Builder
    private func providerIcon(for identifier: String) -> some HTML.View {
        HTML.Empty()
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

// Namespace for OAuth views
extension Identity.OAuth {
    public enum Login {}
}
