//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/08/2024.
//

import Foundation
import HTML
import IdentitiesTypes
import Identity_Shared
import Language
import Server
import Translating
import Webpage

extension Identity.View {
    public struct HTMLDocument<
        Body: HTML.View
    >: HTML.Document.`Protocol` {
        let view: Identity.View
        let title: (Identity.View) -> String
        let description: (Identity.View) -> String
        let _body: Body
        //        let favicons: Favicons
        let canonicalHref: (Identity.View) -> URL?
        let hreflang: (Identity.View, Language) -> URL
        let footerLinks: [(TranslatedString, URL)]

        @Dependency(\.language) var language
        @Dependency(\.languages) var languages

        // The retired HTMLTheme `\.theme` DependencyValues key is gone. On the institute surface the
        // theme is a TaskLocal-backed static rather than a dependency — `DarkModeColor.theme` reads
        // `DarkModeColor.Theme.current` (swift-css/Sources/CSS Theming/Color.Theme.swift:247-251).
        // Scope a non-default theme with `DarkModeColor.Theme.withValue(_:operation:)` (ibid. :312+).
        var themeColor: DarkModeColor { DarkModeColor.theme.branding.primary }

        package init(
            view: Identity.View,
            title: @escaping (Identity.View) -> String,
            description: @escaping (Identity.View) -> String,
            //            favicons: Favicons,
            canonicalHref: @escaping (Identity.View) -> URL?,
            hreflang: @escaping (Identity.View, Language) -> URL,
            footerLinks: [(TranslatedString, URL)],
            @HTML.Builder body: () async throws -> Body
        ) async throws {
            self.view = view
            self.title = title
            self.description = description
            self._body = try await body()
            //            self.favicons = favicons
            self.canonicalHref = canonicalHref
            self.hreflang = hreflang
            self.footerLinks = footerLinks
        }

        public var head: some HTML.View {
            meta(charset: .utf8)

            BaseStyles()

            if let canonicalHref = canonicalHref(view) {
                link(
                    href: .init(canonicalHref.absoluteString),
                    rel: .canonical
                )
            }

            for lx in self.languages.filter({ $0 != language }) {
                link(
                    href: .init(hreflang(view, lx).absoluteString),
                    hreflang: .init(value: lx.value),
                    rel: .alternate,
                )
            }

            meta(
                name: .themeColor,
                content: .init(themeColor.light.description),
                media: "(prefers-color-scheme: light)"
            )

            meta(
                name: .themeColor,
                content: .init(themeColor.dark.description),
                media: "(prefers-color-scheme: dark)"
            )

            meta(
                name: .viewport,
                content: "width=device-width, initial-scale=1.0, viewport-fit=cover"
            )

            Style {
                """

                body, html {
                    background: \(DarkModeColor.theme.background.primary.light.description);
                }

                @media (prefers-color-scheme: dark) {
                    body, html {
                        background: \(DarkModeColor.theme.background.primary.dark.description);
                    }
                }

                """
            }
        }

        public var body: some HTML.View {
            // The `.dependency(\.language, language)` view modifier is retired: it has no institute
            // counterpart (swift-webpage/Sources/Webpage/Link.swift:11-14 records the drop). It
            // re-injected the value read from `@Dependency(\.language)` above — i.e. from the very
            // same ambient scope the subtree renders in — so dropping it is behaviour-preserving for
            // in-request rendering. To render under a DIFFERENT language, wrap the render call in
            // `withDependencies { $0.language = … }`.
            HTML.Group {
                _body

                Identity.View.Footer(links: footerLinks)
            }
            .linkColor(.branding.primary)
        }
    }
}
