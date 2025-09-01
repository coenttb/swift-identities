//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/08/2024.
//

import IdentitiesTypes
import Boiler
import Identity_Shared
import CoenttbHTML
import Coenttb_Web
import Language

extension Identity.View {
    public struct HTMLDocument<
        Body: HTML
    >: HTMLDocumentProtocol {
        let view: Identity.View
        let title: (Identity.View) -> String
        let description: (Identity.View) -> String
        let _body: Body
        
        // Configuration properties (no longer using @Dependency)
        let favicons: Favicons
        let canonicalHref: (Identity.View) -> URL?
        let hreflang: (Identity.View, Language) -> URL
        let footer_links: [(TranslatedString, URL)]
        @Dependency(\.language) var language
        @Dependency(\.languages) var languages

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
            CoenttbWebHTMLDocumentHeader(
                title: title(view),
                description: description(view),
                canonicalHref: canonicalHref(view),
                rssXml: nil,
                themeColor: .branding.accent,
                language: language,
                hreflang: { language in hreflang(view, language) },
                styles: { HTMLEmpty() },
                scripts: { fontAwesomeScript },
                favicons: { favicons }
            )
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
