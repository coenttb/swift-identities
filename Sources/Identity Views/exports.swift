//
//  exports.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

@_exported import HTML
@_exported import Webpage
@_exported import IdentitiesTypes
@_exported import ServerFoundationVapor

// MARK: - Component disambiguation
//
// `Webpage` itself re-exports the `HTML` umbrella
// (swift-webpage/Sources/Webpage/exports.swift: `@_exported import HTML`), so the WHATWG
// element types and the Webpage component types of the same name are BOTH top-level and
// BOTH in scope at every call site in this module. The collision is intrinsic: dropping
// `import HTML` here cannot avoid it.
//
// Six names collide (Webpage component vs WHATWG HTML element):
//     Button, Header, Input, Label, Link, Paragraph
// `Label` has no bare call site in this module and is deliberately NOT aliased.
//
// A module-local declaration shadows imported ones in unqualified lookup, so these five
// typealiases bind every bare call site in `Identity Views` to the Webpage component
// without annotating the ~113 sites individually.
//
// They are `internal` on purpose. Making them `public` would re-export a THIRD candidate
// into Identity Frontend/Consumer/Standalone and make the ambiguity there worse rather
// than better — those modules each need their own local aliases when their wave lands.

internal typealias Paragraph<Content: HTML.View> = Webpage.Paragraph<Content>
internal typealias Header<Content: HTML.View> = Webpage.Header<Content>
internal typealias Link<Content: HTML.View> = Webpage.Link<Content>
internal typealias Button<Title: HTML.View, Icon: HTML.View> = Webpage.Button<Title, Icon>
internal typealias Input<Key: RawRepresentable> = Webpage.Input<Key> where Key.RawValue == String
