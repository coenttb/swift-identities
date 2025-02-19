//
//  File.swift
//  swift-identity
//
//  Created by Coen ten Thije Boonkkamp on 07/02/2025.
//

import BearerAuth
import Foundation
import SwiftWeb
import URLRouting

extension Identity.API {
    /// Authentication endpoints for managing user sessions and access.
    ///
    /// The `Authenticate` API provides three authentication methods:
    /// - Username/password credentials
    /// - JWT tokens (access and refresh)
    /// - API keys
    ///
    /// Each authentication method follows RESTful conventions and returns
    /// standardized authentication responses. For example:
    ///
    /// ```swift
    /// // Authenticate with credentials
    /// let auth = Identity.API.Authenticate.credentials(
    ///   .init(username: "user@example.com", password: "password123")
    /// )
    ///
    /// // Authenticate with a refresh token
    /// let auth = Identity.API.Authenticate.token(.refresh(bearerToken))
    /// ```
    public enum Authenticate: Equatable, Sendable {
        
        /// Authenticates using username/password credentials
        case credentials(Identity.Authentication.Credentials)
        
        /// Authenticates using JWT tokens (access or refresh)
        case token(Identity.API.Authenticate.Token)
        
        /// Authenticates using an API key
        case apiKey(BearerAuth)
    }
}

extension Identity.API.Authenticate {
    /// Token-based authentication methods.
    ///
    /// Supports two types of JWT tokens:
    /// - Access tokens for direct API authentication
    /// - Refresh tokens for obtaining new access tokens
    ///
    /// Access tokens have shorter lifetimes but grant full API access, while
    /// refresh tokens have longer lifetimes but can only be used to obtain new
    /// access tokens.
    public enum Token: Codable, Hashable, Sendable {
        /// Authenticates using a JWT access token
        case access(BearerAuth)
        
        /// Authenticates using a JWT refresh token to obtain a new access token
        case refresh(BearerAuth)
    }
}

extension Identity.API.Authenticate {
    /// Routes authentication requests to their appropriate handlers.
    ///
    /// Defines the URL structure and request/response formats for all authentication
    /// endpoints:
    ///
    /// - Credentials: `POST /authenticate` with form-encoded credentials
    /// - Access Token: `POST /authenticate/access` with bearer token
    /// - Refresh Token: `POST /authenticate/refresh` with bearer token
    /// - API Key: `POST /authenticate/api-key` with bearer token
    ///
    /// All authentication endpoints use POST methods for security and accept
    /// appropriate authentication data in their request bodies.
    public struct Router: ParserPrinter, Sendable {

        public init() {}

        /// The routing logic for authentication endpoints.
        ///
        /// Routes are composed using the `OneOf` parser-printer to match requests
        /// against the supported authentication methods. Each route specifies:
        /// - The HTTP method (POST for all auth endpoints)
        /// - The path components
        /// - The request body format
        public var body: some URLRouting.Router<Identity.API.Authenticate> {
            OneOf {
                URLRouting.Route(.case(Identity.API.Authenticate.credentials)) {
                    Method.post
                    Body(.form(Identity.Authentication.Credentials.self, decoder: .default))
                }

                URLRouting.Route(.case(Identity.API.Authenticate.token)) {
                    Method.post
                    OneOf {
                        URLRouting.Route(.case(Identity.API.Authenticate.Token.access)) {
                            Path.access
                            BearerAuth.Router()
                        }

                        URLRouting.Route(.case(Identity.API.Authenticate.Token.refresh)) {
                            Path.refresh
                            BearerAuth.Router()
                        }
                    }
                }

                URLRouting.Route(.case(Identity.API.Authenticate.apiKey)) {
                    Path.apiKey
                    BearerAuth.Router()
                }
            }
        }
    }
}
