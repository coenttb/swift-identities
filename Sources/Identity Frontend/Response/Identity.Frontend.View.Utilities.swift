//
//  Identity.Frontend.View.Utilities.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 22/08/2025.
//

import ServerFoundationVapor
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web
import Identity_Views
import Dependencies
import Language

extension Identity.Frontend {
    /// Creates an HTML document wrapper for identity views.
    /// This shared utility is used by both Frontend handlers and Standalone handlers.
    public static func htmlDocument<Content: HTML>(
        for view: Identity.View,
        configuration: Identity.Frontend.Configuration,
        @HTMLBuilder content: () async throws -> Content
    ) async throws -> any AsyncResponseEncodable {
        return try await htmlDocument(
            for: view,
            branding: configuration.branding,
            canonicalHref: configuration.canonicalHref,
            hreflang: configuration.hreflang,
            footer_links: configuration.branding.footer_links,
            content: content
        )
    }
    
    /// Creates an HTML document wrapper with explicit parameters.
    public static func htmlDocument<Content: HTML>(
        for view: Identity.View,
        branding: Identity.Frontend.Configuration.Branding,
        canonicalHref: @Sendable @escaping (Identity.View) -> URL?,
        hreflang: @Sendable @escaping (Identity.View, Translating.Language) -> URL,
        footer_links: [(TranslatedString, URL)],
        @HTMLBuilder content: () async throws  -> Content
    ) async throws -> any AsyncResponseEncodable {
        return try await Identity.View.HTMLDocument(
            view: view,
            title: { view in
                switch view {
                case .authenticate: return "Sign In"
                case .create: return "Create Account"
                case .delete: return "Delete Account"
                case .logout: return "Sign Out"
                case .email: return "Change Email"
                case .password: return "Password"
                case .mfa: return "MFA"
                }
            },
            description: { view in
                switch view {
                case .authenticate: return "Sign in to your account"
                case .create: return "Create a new account"
                case .delete: return "Delete your account"
                case .logout: return "Sign out of your account"
                case .email: return "Change your email address"
                case .password: return "Manage your password"
                case .mfa: return "MFA"
                }
            },
            favicons: branding.favicons,
            canonicalHref: canonicalHref,
            hreflang: hreflang,
            footer_links: footer_links
        ) {
            try await content()
        }
    }
    
    /// Creates an HTML document wrapper with custom title and description.
    public static func htmlDocument<Content: HTML>(
        for view: Identity.View,
        title: String,
        description: String,
        configuration: Identity.Frontend.Configuration,
        @HTMLBuilder content: () async throws -> Content
    ) async throws -> any AsyncResponseEncodable {
        return try await Identity.View.HTMLDocument(
            view: view,
            title: { _ in title },
            description: { _ in description },
            favicons: configuration.branding.favicons,
            canonicalHref: configuration.canonicalHref,
            hreflang: configuration.hreflang,
            footer_links: configuration.branding.footer_links
        ) {
            try await content()
        }
    }
}
