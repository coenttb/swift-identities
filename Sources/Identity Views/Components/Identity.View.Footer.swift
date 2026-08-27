//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 15/09/2024.
//

import Foundation
import HTML
import Translating
import Webpage

extension Identity.View {
    public struct Footer: HTML.View {
        let links: [(TranslatedString, URL)]

        public init(links: [(TranslatedString, URL)]) {
            self.links = links
        }

        public var body: some HTML.View {
            footer {
                if !links.isEmpty {
                    HStack {
                        for (index, link) in links.enumerated() {
                            FooterLink(index: index, link: link, count: links.count)
                        }
                    }
                    .css
                    .maxWidth(.px(800))
                    .margin(horizontal: .auto)
                    .padding(.rem(1))
                }
            }
            .css
            .font(.body(.small))
            .color(.gray600)
            .fontWeight(.light)
        }
    }
}

// MARK: - Concrete list-item type
//
// `Render.Builder.buildArray(_:) -> [V]`
// (swift-render/Sources/Render Primitive/Render.Builder.swift:43) must reify a
// concrete element type `V`. The loop body here used to be the inline separator + `Link` pair,
// whose type is OPAQUE (the `.css` chains return `HTML.CSS<some HTML.View>`), and an opaque
// element cannot be reified inside `buildArray` while the enclosing `body`'s own opaque type is
// still under inference.
//
// This needs no special handling versus the OAuth loops, despite also using `buildOptional`
// (`if index > 0`): the conditional moves INSIDE this struct's body, where it is an ordinary
// builder conditional that `buildArray` never sees. One fix covers all four sites.
//
// `body` produces a `Render._Tuple` (optional separator + link), which renders its children in
// sequence with no wrapping element — so the flex layout of the enclosing `HStack` is unchanged.

private struct FooterLink: HTML.View {
    let index: Int
    let link: (TranslatedString, URL)
    let count: Int

    var body: some HTML.View {
        if index > 0 {
            div {
                "|"
            }
            .css
            .color(.text.primary)
            .width(.rem(1))
            .textAlign(.center)
            .padding(vertical: nil, horizontal: .rem(0.5))
        }

        Link(
            link.0.capitalizingFirstLetter().description,
            href: .init(link.1.absoluteString)
        )
        .css
        .inlineStyle("flex", "1")
        .textAlign(count == 1 ? .center : index == 0 ? .right : .left)
    }
}

extension Identity.View.Footer {
    public init(termsOfUse: URL?, privacyStatement: URL?) {
        var links: [(TranslatedString, URL)] = []

        if let termsOfUse {
            links.append((String.terms_of_use, termsOfUse))
        }

        if let privacyStatement {
            links.append((String.privacyStatement, privacyStatement))
        }

        self.init(links: links)
    }
}
