//
//  Identity.View.HTMLDocument+Consumer.swift
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
    /// Convenience initializer for Consumer that uses dependencies for configuration.
    ///
    /// This initializer allows Consumer to create HTMLDocument instances without
    /// manually passing all configuration parameters, instead pulling them from
    /// the Consumer's dependency configuration.
    package init(
        view: Identity.View,
        title: @escaping (Identity.View) -> String,
        description: @escaping (Identity.View) -> String,
        @HTMLBuilder body: () -> Body
    ) {
        @Dependency(\.identity.consumer.branding.favicons) var favicons: Favicons
        @Dependency(\.identity.consumer.canonicalHref) var canonicalHref
        @Dependency(\.identity.consumer.hreflang) var hreflang
        @Dependency(\.identity.consumer.branding.footer_links) var footer_links: [(TranslatedString, URL)]
        @Dependency(\.language) var language
        @Dependency(\.languages) var languages
        
        self.init(
            view: view,
            title: title,
            description: description,
            favicons: favicons,
            canonicalHref: { view in canonicalHref(view) },
            hreflang: { view, lang in hreflang(view, lang) },
            footer_links: footer_links,
            body: body
        )
    }
}
