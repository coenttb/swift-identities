//
//  Identity.Consumer.CookieReader.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import Vapor
import ServerFoundationVapor
import Identity_Shared
import IdentitiesTypes

extension Identity.Consumer {
    /// Cookie reader for Consumer applications.
    ///
    /// Consumer only needs to:
    /// - Read cookies from incoming requests
    /// - Forward cookies to Provider API calls
    /// - Clear cookies on logout
    ///
    /// Consumer doesn't need to know about cookie setting details
    /// like SameSite policies or security settings - those are
    /// handled by the Provider.
    public struct CookieReader: Sendable {
        
        public init() {}
        
        /// Read the access token from request cookies
        public func accessToken(from request: Request) -> String? {
            request.cookies[Identity.Cookies.Names.accessToken]?.string
        }
        
        /// Read the refresh token from request cookies
        public func refreshToken(from request: Request) -> String? {
            request.cookies[Identity.Cookies.Names.refreshToken]?.string
        }
        
        /// Read the reauthorization token from request cookies
        public func reauthorizationToken(from request: Request) -> String? {
            request.cookies[Identity.Cookies.Names.reauthorizationToken]?.string
        }
        
        /// Check if any identity cookies are present
        public func identityCookies(in request: Request) -> Bool {
            accessToken(from: request) != nil ||
            refreshToken(from: request) != nil ||
            reauthorizationToken(from: request) != nil
        }
        
        /// Forward identity cookies from incoming request to outgoing API request.
        /// This is used when the Consumer needs to call the Provider API.
        public func forwardCookies(
            from request: Request,
            to urlRequest: inout URLRequest
        ) {
            var cookieStrings: [String] = []
            
            // Forward access token if present
            if let token = accessToken(from: request) {
                cookieStrings.append("\(Identity.Cookies.Names.accessToken)=\(token)")
            }
            
            // Forward refresh token if present
            if let token = refreshToken(from: request) {
                cookieStrings.append("\(Identity.Cookies.Names.refreshToken)=\(token)")
            }
            
            // Forward reauthorization token if present
            if let token = reauthorizationToken(from: request) {
                cookieStrings.append("\(Identity.Cookies.Names.reauthorizationToken)=\(token)")
            }
            
            // Also forward any identity metadata cookies (prefixed)
            let identityCookies = request.cookies.all.filter { 
                $0.key.hasPrefix(Identity.Cookies.Names.identityPrefix)
            }
            for cookie in identityCookies {
                cookieStrings.append("\(cookie.key)=\(cookie.value.string)")
            }
            
            // Set the Cookie header if we have any cookies to forward
            if !cookieStrings.isEmpty {
                urlRequest.setValue(cookieStrings.joined(separator: "; "), forHTTPHeaderField: "Cookie")
            }
        }
        
        /// Clear all identity-related cookies in the response.
        /// This is typically called during logout.
        public func clearAll(in response: inout Response) {
            // Clear main identity cookies
            response.cookies[Identity.Cookies.Names.accessToken] = .expired
            response.cookies[Identity.Cookies.Names.refreshToken] = .expired
            response.cookies[Identity.Cookies.Names.reauthorizationToken] = .expired
        }
        
        /// Clear all identity-related cookies by setting headers directly.
        /// This provides more control over the clearing process.
        public func clearAll(headers: inout HTTPHeaders) {
            // Clear main tokens with explicit Max-Age=0
            headers.add(
                name: .setCookie,
                value: "\(Identity.Cookies.Names.accessToken)=; Path=/; Max-Age=0; HttpOnly; SameSite=Strict"
            )
            headers.add(
                name: .setCookie,
                value: "\(Identity.Cookies.Names.refreshToken)=; Path=/; Max-Age=0; HttpOnly; SameSite=Strict"
            )
            headers.add(
                name: .setCookie,
                value: "\(Identity.Cookies.Names.reauthorizationToken)=; Path=/; Max-Age=0; HttpOnly; SameSite=Strict"
            )
        }
        
        /// Extract identity cookies for logging/debugging (redacted).
        /// Never log actual token values.
        public func debugDescription(for request: Request) -> String {
            var parts: [String] = []
            
            if let _ = accessToken(from: request) {
                parts.append("access_token=<redacted>")
            }
            if let _ = refreshToken(from: request) {
                parts.append("refresh_token=<redacted>")
            }
            if let _ = reauthorizationToken(from: request) {
                parts.append("reauthorization_token=<redacted>")
            }
            
            let identityCookies = request.cookies.all.filter { 
                $0.key.hasPrefix(Identity.Cookies.Names.identityPrefix)
            }
            for cookie in identityCookies {
                parts.append("\(cookie.key)=<redacted>")
            }
            
            return parts.isEmpty ? "No identity cookies" : parts.joined(separator: ", ")
        }
    }
}

// MARK: - Validation Helpers

extension Identity.Consumer.CookieReader {
    
    /// Validate that required cookies are present for authentication
    public func validateAuthenticationCookies(in request: Request) throws {
        guard accessToken(from: request) != nil else {
            throw Identity.Consumer.CookieError.missingAccessToken
        }
        // Refresh token is optional for some operations
    }
    
    /// Validate that required cookies are present for token refresh
    public func validateRefreshCookies(in request: Request) throws {
        guard refreshToken(from: request) != nil else {
            throw Identity.Consumer.CookieError.missingRefreshToken
        }
    }
    
    /// Validate that required cookies are present for reauthorization
    public func validateReauthorizationCookies(in request: Request) throws {
        guard reauthorizationToken(from: request) != nil else {
            throw Identity.Consumer.CookieError.missingReauthorizationToken
        }
    }
}

// MARK: - Cookie Errors

extension Identity.Consumer {
    public enum CookieError: Error, CustomStringConvertible {
        case missingAccessToken
        case missingRefreshToken
        case missingReauthorizationToken
        
        public var description: String {
            switch self {
            case .missingAccessToken:
                return "Access token cookie is missing. User may need to log in."
            case .missingRefreshToken:
                return "Refresh token cookie is missing. User may need to log in again."
            case .missingReauthorizationToken:
                return "Reauthorization token cookie is missing. User needs to reauthorize this operation."
            }
        }
    }
}
