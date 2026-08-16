//
//  Cookies.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 18/08/2025.
//

import Foundation
import HTTP_Cookies
import IdentitiesTypes
import Identity_Frontend
import Identity_Shared
import Server_Vapor
import URLRouting

extension Identity.Frontend.Configuration.Cookies {
    /// Configuration for Consumer applications that connect to an Identity Provider.
    /// Designed to handle cookies set by a separate Provider service.
    public static func consumer(
        domain: String? = nil,
        router: any ParserPrinter<URLRequestData, Identity.Route>,
        // swiftlint:disable:previous no_any_protocol_existential
        crossOrigin: Bool = false
    ) -> Self {
        // Calculate refresh token path from router
        let refreshPath: String = {
            // Create a dummy token just to get the path
            let dummyToken: JWT = .init(
                header: .init(alg: ""),
                payload: .init(),
                signature: Foundation.Data()
            )
            return router.url(
                for: .api(.authenticate(.token(.refresh(dummyToken))))
            ).path
        }()

        // For cross-origin scenarios, use less restrictive SameSite policy
        let sameSitePolicy: HTTP_Cookies.HTTPCookies.SameSitePolicy = crossOrigin ? .none : .lax

        return Self(
            accessToken: .init(
                maxAge: 60 * 15,
                domain: domain,
                path: "/",
                isSecure: true,  // Always secure for Consumer/Provider pattern
                isHTTPOnly: true,
                sameSitePolicy: sameSitePolicy
            ),
            refreshToken: .init(
                maxAge: 60 * 60 * 24 * 30,
                domain: domain,
                path: refreshPath,
                isSecure: true,
                isHTTPOnly: true,
                sameSitePolicy: sameSitePolicy
            ),
            reauthorizationToken: .init(
                maxAge: 60 * 5,
                domain: domain,
                path: "/",
                isSecure: true,
                isHTTPOnly: true,
                sameSitePolicy: .strict  // Always strict for reauthorization
            )
        )
    }

    /// Development configuration for Consumer applications.
    /// More relaxed settings for local development but still maintains separation concerns.
    public static func consumerDevelopment(
        router: any ParserPrinter<URLRequestData, Identity.Route>
        // swiftlint:disable:previous no_any_protocol_existential
    ) -> Self {
        // Calculate refresh token path from router
        let refreshPath: String = {
            // Create a dummy token just to get the path
            let dummyToken: JWT = .init(
                header: .init(alg: ""),
                payload: .init(),
                signature: Foundation.Data()
            )
            return router.url(
                for: .api(.authenticate(.token(.refresh(dummyToken))))
            ).path
        }()

        return Self(
            accessToken: .init(
                maxAge: 60 * 15,
                domain: nil,
                path: "/",
                isSecure: false,  // Allow HTTP for development
                isHTTPOnly: true,
                sameSitePolicy: .none  // Allow cross-origin for development
            ),
            refreshToken: .init(
                maxAge: 60 * 60 * 24 * 30,
                domain: nil,
                path: refreshPath,
                isSecure: false,
                isHTTPOnly: true,
                sameSitePolicy: .none
            ),
            reauthorizationToken: .init(
                maxAge: 60 * 5,
                domain: nil,
                path: "/",
                isSecure: false,
                isHTTPOnly: true,
                sameSitePolicy: .lax  // Slightly more restrictive for reauth
            )
        )
    }
}
