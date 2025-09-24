//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/09/2024.
//

import Foundation
import IdentitiesTypes
import HTML
import HTMLWebsite

extension Identity.View {
    public struct Logo: HTML, Sendable {
        let logo: any HTML & Sendable
        let href: URL

        public init(
            logo: any HTML & Sendable,
            href: URL
        ) {
            self.logo = logo
            self.href = href
        }

        public var body: some HTML {
            VStack {
                Link(href: .init(href.relativePath)) {
                    AnyHTML(logo)
                }
                .linkColor(.text.primary)
                .display(.inlineBlock)
                .margin(horizontal: .auto)
            }
        }
    }
}
