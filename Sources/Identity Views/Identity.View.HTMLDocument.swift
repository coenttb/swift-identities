//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/08/2024.
//

import IdentitiesTypes
import Identity_Shared
import ServerFoundation
import HTML
import HTMLTheme
import HTMLWebsite
import Language

extension Identity.View {
    public struct HTMLDocument<
        Body: HTML
    >: HTMLDocumentProtocol {
        let view: Identity.View
        let title: (Identity.View) -> String
        let description: (Identity.View) -> String
        let _body: Body
        let favicons: Favicons
        let canonicalHref: (Identity.View) -> URL?
        let hreflang: (Identity.View, Language) -> URL
        let footer_links: [(TranslatedString, URL)]
        
        @Dependency(\.language) var language
        @Dependency(\.languages) var languages
        @Dependency(\.theme.branding.primary) var themeColor
        
        package init(
            view: Identity.View,
            title: @escaping (Identity.View) -> String,
            description: @escaping (Identity.View) -> String,
            favicons: Favicons,
            canonicalHref: @escaping (Identity.View) -> URL?,
            hreflang: @escaping (Identity.View, Language) -> URL,
            footer_links: [(TranslatedString, URL)],
            @HTMLBuilder body: () async throws  -> Body
        ) async throws {
            self.view = view
            self.title = title
            self.description = description
            self._body = try await body()
            self.favicons = favicons
            self.canonicalHref = canonicalHref
            self.hreflang = hreflang
            self.footer_links = footer_links
        }

        public var head: some HTML {
            meta(charset: .utf8)()
            
            BaseStyles()
            
            if let canonicalHref = canonicalHref(view) {
                link(
                    href: .init(canonicalHref.absoluteString),
                    rel: .canonical
                )()
            }
            
            HTMLForEach(self.languages.filter { $0 != language }) { lx in
                link(
                    href: .init(hreflang(view, lx).absoluteString),
                    hreflang: .init(value: lx.rawValue),
                    rel: .alternate,
                )()
            }
            
            meta(
                name: .themeColor,
                content: .init(themeColor.light.description),
                media: "(prefers-color-scheme: light)"
            )()
            
            meta(
                name: .themeColor,
                content: .init(themeColor.dark.description),
                media: "(prefers-color-scheme: dark)"
            )()
            
            meta(
                name: .viewport,
                content: "width=device-width, initial-scale=1.0, viewport-fit=cover"
            )()
        }

        public var body: some HTML {
            HTMLGroup {
                _body

                Identity.View.Footer(links: footer_links)
            }
            .dependency(\.language, language)
            .linkColor(.branding.primary)
        }
    }
}
