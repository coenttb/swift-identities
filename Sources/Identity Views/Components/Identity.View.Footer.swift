//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 15/09/2024.
//

import Foundation
import CoenttbHTML

extension Identity.View {
    public struct Footer: HTML {
        let links: [(TranslatedString, URL)]

        public init(links: [(TranslatedString, URL)]) {
            self.links = links
        }

        public var body: some HTML {
            footer {
                if !links.isEmpty {
                    HStack {
                        HTMLForEach(Array(links.enumerated())) { index, link in
                            if index > 0 {
                                div { "|" }
                                    .width(.rem(1))
                                    .textAlign(.center)
                                    .padding(vertical: nil, horizontal: .rem(0.5))
                            }

                            Link(link.0.capitalizingFirstLetter().description,
                                 href: .init(link.1.absoluteString))
                                .inlineStyle("flex", "1")
                                .textAlign(links.count == 1 ? .center :
                                         index == 0 ? .right : .left)
                        }
                    }
                    .maxWidth(.px(800))
                    .margin(horizontal: .auto)
                    .padding(.rem(1))
                }
            }
            .font(.body(.small))
            .color(.gray600)
            .fontWeight(.light)
        }
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
