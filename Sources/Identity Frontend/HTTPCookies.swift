//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 11/02/2025.
//

import Foundation
import HTTP_Cookies
import HTTP_Standard
import IdentitiesTypes
import Server_Vapor
import Vapor

import enum Server.Server

extension Server.Response {
    /// A copy of this response with one `Set-Cookie` line appended for `token`
    /// under `configuration`.
    ///
    /// Attributes come entirely from `configuration`; the token value is a
    /// JWT compact serialization, which is always within the RFC 6265
    /// cookie-octet set, so `.raw` rendering cannot fail for these call sites.
    package func setting(
        cookie name: String,
        token: String,
        configuration: HTTP_Cookies.HTTPCookies.Configuration
    ) -> Server.Response {
        var copy = self
        let headerValue: String
        do {
            headerValue = try HTTP_Cookies.HTTPCookies.SetCookie(
                name: name,
                value: .init(token: token),
                configuration: configuration
            ).headerValue()
        } catch {
            preconditionFailure("Set-Cookie rendering failed for a JWT cookie value: \(error)")
        }
        copy.headers.append(
            HTTP.Header.Field(name: .init("Set-Cookie"), value: .init(unchecked: headerValue))
        )
        return copy
    }

    /// A copy of this response with expired `Set-Cookie` lines for every
    /// identity cookie, deleting them client-side (logout).
    package func expiringIdentityCookies() -> Server.Response {
        var copy = self
        for name in [
            Identity.Cookies.Names.accessToken,
            Identity.Cookies.Names.refreshToken,
            Identity.Cookies.Names.reauthorizationToken,
        ] {
            copy = copy.setting(
                cookie: name,
                token: "",
                configuration: .init(
                    expires: Date(timeIntervalSince1970: 0).rfc1123,
                    maxAge: 0,
                    path: "/",
                    isSecure: false,
                    isHTTPOnly: true,
                    sameSitePolicy: .lax
                )
            )
        }
        return copy
    }
}

extension Vapor.HTTPCookies {
    /// The identity access-token cookie, read from an inbound request's cookie jar.
    package var accessToken: Vapor.HTTPCookies.Value? {
        get { self[Identity.Cookies.Names.accessToken] }
        set { self[Identity.Cookies.Names.accessToken] = newValue }
    }

    /// The identity refresh-token cookie, read from an inbound request's cookie jar.
    package var refreshToken: Vapor.HTTPCookies.Value? {
        get { self[Identity.Cookies.Names.refreshToken] }
        set { self[Identity.Cookies.Names.refreshToken] = newValue }
    }

    /// The identity reauthorization-token cookie, read from an inbound request's cookie jar.
    package var reauthorizationToken: Vapor.HTTPCookies.Value? {
        get { self[Identity.Cookies.Names.reauthorizationToken] }
        set { self[Identity.Cookies.Names.reauthorizationToken] = newValue }
    }
}
