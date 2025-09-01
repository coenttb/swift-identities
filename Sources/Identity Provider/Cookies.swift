//
//  Cookies.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 18/08/2025.
//

import Foundation
import Identity_Shared
import Identity_Backend
import ServerFoundationVapor
import URLRouting
import IdentitiesTypes

extension Identity.Provider {
    /// Cookie configuration for Provider services that serve identity to Consumer apps.
    ///
    /// Provider is responsible for:
    /// - Setting secure cookies that Consumer apps will receive
    /// - Configuring cross-origin policies based on deployment mode
    /// - Restricting cookie paths for security
    public struct CookieSettings: Sendable {
        public var accessToken: HTTPCookies.Configuration
        public var refreshToken: HTTPCookies.Configuration
        public var reauthorizationToken: HTTPCookies.Configuration
        
        public init(
            accessToken: HTTPCookies.Configuration,
            refreshToken: HTTPCookies.Configuration,
            reauthorizationToken: HTTPCookies.Configuration
        ) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.reauthorizationToken = reauthorizationToken
        }
        
        /// Create cookie settings based on deployment mode.
        ///
        /// This factory method automatically configures:
        /// - SameSite policies based on cross-origin requirements
        /// - Domain settings for cookie scope
        /// - Path restrictions for security
        /// - HTTPS requirements for production
        public static func forDeployment(
            _ mode: Identity.Cookies.DeploymentMode,
            router: AnyParserPrinter<URLRequestData, Identity.Route>
        ) -> Self {
            switch mode {
            case .sameOrigin:
                return sameOrigin(router: router)
                
            case .crossSubdomain(let parentDomain):
                return crossSubdomain(parentDomain: parentDomain, router: router)
                
            case .crossDomain:
                return crossDomain(router: router)
                
            case .development:
                return development(router: router)
            }
        }
        
        /// Same-origin configuration (Provider and Consumer on same domain).
        /// Uses strict SameSite policy for maximum security.
        public static func sameOrigin(
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
        
        /// Cross-subdomain configuration (e.g., api.example.com and app.example.com).
        /// Sets parent domain to allow cookie sharing between subdomains.
        public static func crossSubdomain(
            parentDomain: String,
            router: AnyParserPrinter<URLRequestData, Identity.Route>
        ) -> Self {
            let refreshPath = Identity.Cookies.Paths.refresh(using: router)
            let reauthorizePath = Identity.Cookies.Paths.reauthorize(using: router)
            
            return Self(
                accessToken: .init(
                    expires: .init(Identity.Cookies.Expiry.accessToken),
                    maxAge: Identity.Cookies.Expiry.accessToken,
                    domain: parentDomain, // Parent domain for subdomain sharing
                    path: "/",
                    isSecure: true,
                    isHTTPOnly: true,
                    sameSitePolicy: .lax // Lax for subdomain communication
                ),
                refreshToken: .init(
                    expires: .init(Identity.Cookies.Expiry.refreshToken),
                    maxAge: Identity.Cookies.Expiry.refreshToken,
                    domain: parentDomain,
                    path: refreshPath,
                    isSecure: true,
                    isHTTPOnly: true,
                    sameSitePolicy: .lax
                ),
                reauthorizationToken: .init(
                    expires: .init(Identity.Cookies.Expiry.reauthorizationToken),
                    maxAge: Identity.Cookies.Expiry.reauthorizationToken,
                    domain: parentDomain,
                    path: reauthorizePath,
                    isSecure: true,
                    isHTTPOnly: true,
                    sameSitePolicy: .strict // Always strict for sensitive operations
                )
            )
        }
        
        /// Cross-domain configuration (completely different domains).
        /// Uses SameSite=None to allow cross-domain cookie sharing.
        /// Warning: Requires HTTPS and proper CORS configuration.
        public static func crossDomain(
            router: AnyParserPrinter<URLRequestData, Identity.Route>
        ) -> Self {
            let refreshPath = Identity.Cookies.Paths.refresh(using: router)
            let reauthorizePath = Identity.Cookies.Paths.reauthorize(using: router)
            
            return Self(
                accessToken: .init(
                    expires: .init(Identity.Cookies.Expiry.accessToken),
                    maxAge: Identity.Cookies.Expiry.accessToken,
                    domain: nil, // No domain restriction for cross-domain
                    path: "/",
                    isSecure: true, // Required for SameSite=None
                    isHTTPOnly: true,
                    sameSitePolicy: .none // Allow cross-domain
                ),
                refreshToken: .init(
                    expires: .init(Identity.Cookies.Expiry.refreshToken),
                    maxAge: Identity.Cookies.Expiry.refreshToken,
                    domain: nil,
                    path: refreshPath,
                    isSecure: true,
                    isHTTPOnly: true,
                    sameSitePolicy: .none
                ),
                reauthorizationToken: .init(
                    expires: .init(Identity.Cookies.Expiry.reauthorizationToken),
                    maxAge: Identity.Cookies.Expiry.reauthorizationToken,
                    domain: nil,
                    path: reauthorizePath,
                    isSecure: true,
                    isHTTPOnly: true,
                    sameSitePolicy: .strict // Keep strict even in cross-domain
                )
            )
        }
        
        /// Development configuration for Provider services.
        /// Allows HTTP and cross-origin for local development.
        public static func development(
            router: AnyParserPrinter<URLRequestData, Identity.Route>
        ) -> Self {
            let refreshPath = Identity.Cookies.Paths.refresh(using: router)
            let reauthorizePath = Identity.Cookies.Paths.reauthorize(using: router)
            
            return Self(
                accessToken: .init(
                    expires: .init(Identity.Cookies.Expiry.accessTokenDevelopment),
                    maxAge: Identity.Cookies.Expiry.accessTokenDevelopment,
                    domain: nil, // Let browser handle for localhost
                    path: "/",
                    isSecure: false, // Allow HTTP for development
                    isHTTPOnly: true,
                    sameSitePolicy: .none // Allow cross-origin for development
                ),
                refreshToken: .init(
                    expires: .init(Identity.Cookies.Expiry.refreshTokenDevelopment),
                    maxAge: Identity.Cookies.Expiry.refreshTokenDevelopment,
                    domain: nil,
                    path: refreshPath,
                    isSecure: false,
                    isHTTPOnly: true,
                    sameSitePolicy: .none
                ),
                reauthorizationToken: .init(
                    expires: .init(Identity.Cookies.Expiry.reauthorizationToken),
                    maxAge: Identity.Cookies.Expiry.reauthorizationToken,
                    domain: nil,
                    path: reauthorizePath,
                    isSecure: false,
                    isHTTPOnly: true,
                    sameSitePolicy: .lax
                )
            )
        }
    }
}
