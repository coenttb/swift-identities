//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/09/2024.
//

import Foundation
import HTML
import IdentitiesTypes
import Webpage

extension Identity.View {
    public struct Logo: HTML.View, Sendable {
        // NOT `any HTML.View & Sendable`. `HTML.View` refines `Render.View`, whose rendering
        // requirement is `static func _render(_ view: borrowing Self, context: inout Render.Context)`
        // — a `Self` in parameter position, which makes the protocol unusable as an existential.
        // The tower states the rule outright: "the ecosystem therefore composes through this
        // concrete eraser plus generics and NEVER through `any HTML.View`"
        // (swift-html-render/Sources/HTML Rendering Core/HTML.AnyView.swift:25-29).
        // `HTML.AnyView` is `@unchecked Sendable` (ibid. :30), so `Logo: Sendable` still holds.
        let logo: HTML.AnyView
        let href: URL

        // Generic over the concrete view so existing call sites keep their shape — passing an
        // already-erased `HTML.AnyView` also works, since re-wrapping is idempotent (ibid. :38-44).
        public init(
            logo: some HTML.View,
            href: URL
        ) {
            self.logo = HTML.AnyView(logo)
            self.href = href
        }

        public var body: some HTML.View {
            VStack {
                Link(href: .init(href.relativePath)) {
                    logo
                }
                .linkColor(.text.primary)
                .display(.inlineBlock)
                .margin(horizontal: .auto)
            }
        }
    }
}
