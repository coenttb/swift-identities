//
//  Cookies.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 18/08/2025.
//

import Foundation
import Identity_Frontend
import Identity_Shared
import ServerFoundationVapor
import URLRouting
import IdentitiesTypes

/// Cookie presets for Standalone identity systems
extension Identity.Frontend.Configuration.Cookies {
    
    /// Create cookie configuration for Standalone deployment based on mode.
    ///
    /// Standalone deployments are self-contained and typically use:
    /// - Same-origin cookies (strict SameSite)
    /// - Simpler path configuration
    /// - No cross-domain concerns
    public static func standalone(
        mode: Identity.Cookies.DeploymentMode = .sameOrigin,
        router: AnyParserPrinter<URLRequestData, Identity.Route>
    ) -> Self {
        switch mode {
        case .sameOrigin:
            return production(router: router)
        case .development:
            return development(router: router)
        case .crossSubdomain, .crossDomain:
            // Standalone typically doesn't use cross-origin, but support it if needed
            return production(router: router)
        }
    }
    
    /// Production configuration for Standalone identity system.
    /// Uses strict security settings with HTTPS requirement.
    public static func production(
        domain: String? = nil,
        router: AnyParserPrinter<URLRequestData, Identity.Route>
    ) -> Self {
        let refreshPath = Identity.Cookies.Paths.refresh(using: router)
        let reauthorizePath = Identity.Cookies.Paths.reauthorize(using: router)
        
        return Self(
            accessToken: .init(
                expires: .init(Identity.Cookies.Expiry.accessToken),
                maxAge: Identity.Cookies.Expiry.accessToken,
                domain: domain,
                path: "/",
                isSecure: true,
                isHTTPOnly: true,
                sameSitePolicy: .strict
            ),
            refreshToken: .init(
                expires: .init(Identity.Cookies.Expiry.refreshToken),
                maxAge: Identity.Cookies.Expiry.refreshToken,
                domain: domain,
                path: refreshPath,
                isSecure: true,
                isHTTPOnly: true,
                sameSitePolicy: .strict
            ),
            reauthorizationToken: .init(
                expires: .init(Identity.Cookies.Expiry.reauthorizationToken),
                maxAge: Identity.Cookies.Expiry.reauthorizationToken,
                domain: domain,
                path: reauthorizePath,
                isSecure: true,
                isHTTPOnly: true,
                sameSitePolicy: .strict
            )
        )
    }
    
    /// Development configuration for Standalone identity system.
    /// Uses relaxed security settings suitable for local development.
    public static func development(
        router: AnyParserPrinter<URLRequestData, Identity.Route>? = nil
    ) -> Self {
       
        return Self(
            accessToken: .init(
                expires: .init(Identity.Cookies.Expiry.accessTokenDevelopment),
                maxAge: Identity.Cookies.Expiry.accessTokenDevelopment,
                domain: nil,
                path: "/",
                isSecure: false, // Allow HTTP for development
                isHTTPOnly: true,
                sameSitePolicy: .lax
            ),
            refreshToken: .init(
                expires: .init(Identity.Cookies.Expiry.refreshTokenDevelopment),
                maxAge: Identity.Cookies.Expiry.refreshTokenDevelopment,
                domain: nil,
                path: "/",
                isSecure: false,
                isHTTPOnly: true,
                sameSitePolicy: .lax
            ),
            reauthorizationToken: .init(
                expires: .init(Identity.Cookies.Expiry.reauthorizationToken),
                maxAge: Identity.Cookies.Expiry.reauthorizationToken,
                domain: nil,
                path: "/",
                isSecure: false,
                isHTTPOnly: true,
                sameSitePolicy: .strict
            )
        )
    }
}
