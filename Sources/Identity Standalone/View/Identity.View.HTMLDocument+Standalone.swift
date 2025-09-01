//
//  Identity.View.HTMLDocument+Standalone.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import IdentitiesTypes
import Boiler
import Identity_Shared
import Identity_Views
import CoenttbHTML
import Coenttb_Web
import Dependencies
import Language

extension Identity.View.HTMLDocument {
    /// Convenience initializer for Standalone that uses configuration parameters.
    ///
    /// This initializer allows Standalone to create HTMLDocument instances by
    /// passing configuration directly, since Standalone doesn't use global dependencies.
    package init(
        view: Identity.View,
        title: @escaping (Identity.View) -> String,
        description: @escaping (Identity.View) -> String,
        configuration: Identity.Standalone.Configuration,
        @HTMLBuilder body: () -> Body
    ) async throws where Self == Identity.View.HTMLDocument<Body> {
        try await self.init(
            view: view,
            title: title,
            description: description,
            favicons: configuration.branding.favicons,
            canonicalHref: { view in configuration.canonicalHref(view) },
            hreflang: { view, lang in configuration.hreflang(view, lang) },
            footer_links: configuration.branding.footer_links,
            body: body
        )
    }
}
