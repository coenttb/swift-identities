//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 17/02/2025.
//

import Identity_Shared
import Dependencies
import Foundation
import IdentitiesTypes
import URLRouting

extension Identity.Provider {
    public struct Configuration: Sendable {
        public var provider: Identity.Provider.Configuration.Provider

        public init(provider: Identity.Provider.Configuration.Provider) {
            self.provider = provider
        }
    }
}

extension Identity.Provider.Configuration {
    public struct Provider: Sendable {
        public var baseURL: URL
        public var domain: String?
        public var issuer: String?
        public var tokens: Identity.Provider.Configuration.Tokens
        public var router: AnyParserPrinter<URLRequestData, Identity.API>
        public var client: Identity.Provider.Client
        public var rateLimiters: RateLimiters

        public init(
            baseURL: URL,
            domain: String?,
            issuer: String?,
            tokens: Identity.Provider.Configuration.Tokens,
            router: AnyParserPrinter<URLRequestData, Identity.API>,
            client: Identity.Provider.Client,
            rateLimiters: RateLimiters = .init()
        ) {
            self.baseURL = baseURL
            self.domain = domain
            self.issuer = issuer
            self.tokens = tokens
            self.router = router.baseURL(baseURL.absoluteString).eraseToAnyParserPrinter()
            self.client = client
            self.rateLimiters = rateLimiters
        }
    }
}

extension Identity.Provider.Configuration: TestDependencyKey {
    public static let testValue: Self = .init(provider: .testValue)
}

extension DependencyValues {
    public var identity: Identity.Provider.Configuration {
        get { self[Identity.Provider.Configuration.self] }
        set { self[Identity.Provider.Configuration.self] = newValue }
    }
}

extension Identity.Provider.Configuration.Provider: TestDependencyKey {
    public static var testValue: Self {

        let router = Identity.API.Router().eraseToAnyParserPrinter()
        let domain: String? = nil

        return .init(
            baseURL: .init(string: "/")!,
            domain: domain,
            issuer: nil,
            tokens: .live(),
            router: router,
            client: .testValue,
            rateLimiters: .init()
        )
    }
}

extension Identity.Provider.Configuration {
    public struct Tokens: Sendable, Hashable {
        public var accessToken: Identity.Provider.Configuration.AccessToken
        public var refreshToken: Identity.Provider.Configuration.RefreshToken
        public var reauthorizationToken: Identity.Provider.Configuration.ReauthorizationToken

        public init(
            accessToken: Identity.Provider.Configuration.AccessToken,
            refreshToken: Identity.Provider.Configuration.RefreshToken,
            reauthorizationToken: Identity.Provider.Configuration.ReauthorizationToken
        ) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.reauthorizationToken = reauthorizationToken
        }
    }
}

extension Identity.Provider.Configuration {
    public struct Token: Sendable, Hashable {
        public var expires: TimeInterval

        public init(
            expires: TimeInterval
        ) {
            self.expires = expires
        }
    }

    public typealias AccessToken = Token
    public typealias RefreshToken = Token
    public typealias ReauthorizationToken = Token
}

extension Identity.Provider.Configuration.Tokens {
    static func live() -> Self {
        .init(
            accessToken: .init(
                expires: 60 * 15
            ),
            refreshToken: .init(
                expires: 60 * 60 * 24 * 30
            ),
            reauthorizationToken: .init(
                expires: 60 * 5
            )
        )
    }
}
