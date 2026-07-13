//
//  URLRouting.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 03/03/2025.
//

import Foundation
import RFC_3986
import ServerFoundationVapor
import URLRouting

extension HTTPHeaders {
    /// Access or set the `Reauthorization: Bearer: ...` header.
    public var reauthorizationToken: BearerAuthorization? {
        get {
            guard let string = self.first(name: .reauthorization) else {
                return nil
            }

            let headerParts = string.split(separator: " ")
            guard headerParts.count == 2 else {
                return nil
            }
            guard headerParts[0].lowercased() == "bearer" else {
                return nil
            }
            return .init(token: String(headerParts[1]))
        }
        set {
            if let bearer = newValue {
                replaceOrAdd(name: .reauthorization, value: "Bearer \(bearer.token)")
            } else {
                remove(name: .reauthorization)
            }
        }
    }
}

extension ParserPrinter where Input == URLRequestData {
    //
    //    /// Sets the access token cookie
    //    /// - Parameter token: Optional access token value
    //    /// - Returns: Modified BaseURLPrinter with access_token cookie
    //    public func setAccessToken(_ token: HTTPCookies.Value?) -> BaseURLPrinter<Self> {
    //        return self.cookie("access_token", token)
    //    }
    //
    //    /// Sets the refresh token cookie
    //    /// - Parameter token: Optional refresh token value
    //    /// - Returns: Modified BaseURLPrinter with refresh_token cookie
    //    public func setRefreshToken(_ token: HTTPCookies.Value?) -> BaseURLPrinter<Self> {
    //        return self.cookie("refresh_token", token)
    //    }
    //
    /// Sets the reauthorization token header
    /// - Parameter token: Optional reauthorization token value
    /// - Returns: Modified parser-printer with Reauthorization header
    public func setReauthorizationToken(_ token: String?) -> HeaderTransform<Self> {
        return transform { urlRequestData in
            if let token = token {
                var data = urlRequestData
                data.headers[HTTPHeaders.Name.reauthorization.description] =
                    ["Bearer \(token)"][...].map { Substring($0) }[...]
                return data
            }
            return urlRequestData
        }
    }
}

extension ParserPrinter where Input == URLRequestData {
    /// Sets or removes the Bearer Authorization header
    /// - Parameter token: The bearer token to use for authentication. If nil, no change is made
    /// - Returns: Modified parser-printer with Authorization header set
    public func setBearerAuth(_ token: String?) -> HeaderTransform<Self> {
        transform { urlRequestData in
            if let token = token {
                var data = urlRequestData
                data.headers["authorization"] = ["Bearer \(token)"][...].map { Substring($0) }[...]
                return data
            }
            return urlRequestData
        }
    }
}

// MARK: - Print-Time Header Transform
//
// `BaseURLPrinter` (bare, unqualified) is a pre-institute-migration symbol: the
// vended replacement is `RFC_3986.URI.BaseURLPrinter`, but that type merges a
// FIXED default `URI.Request.Data` at print time (see `baseURL`/`baseRequestData`
// on `Parser.Bidirectional`) — it isn't a general per-call transform combinator,
// so it isn't the right fit for `setReauthorizationToken`/`setBearerAuth`, which
// apply a runtime closure over the printed request data. The upstream
// `swift-url-routing` package does not vend a generic print-time `transform`
// combinator either (verified: no `func transform` anywhere in that package).
// `HeaderTransform` is the local "router-wrapping type" that restores the prior
// `transform { ... }` call shape on top of the vended `ParserPrinter` surface:
// parsing delegates unchanged to `upstream`; printing prints via `upstream` then
// applies `transform` to the resulting request data.
extension ParserPrinter where Input == URLRequestData {
    fileprivate func transform(
        _ transform: @escaping @Sendable (URLRequestData) -> URLRequestData
    ) -> HeaderTransform<Self> {
        HeaderTransform(upstream: self, transform: transform)
    }
}

public struct HeaderTransform<Upstream: ParserPrinter>: ParserPrinter
where Upstream.Input == URLRequestData {
    public typealias Input = URLRequestData
    public typealias Output = Upstream.Output
    public typealias Body = Never

    @usableFromInline
    let upstream: Upstream

    @usableFromInline
    let transform: @Sendable (URLRequestData) -> URLRequestData

    @usableFromInline
    init(upstream: Upstream, transform: @escaping @Sendable (URLRequestData) -> URLRequestData) {
        self.upstream = upstream
        self.transform = transform
    }

    @inlinable
    public func parse(_ input: inout URLRequestData) throws(RFC_3986.URI.Routing.Error) -> Upstream.Output {
        try upstream.parse(&input)
    }

    @inlinable
    public func print(_ output: Upstream.Output, into input: inout URLRequestData) throws(RFC_3986.URI.Routing.Error) {
        try upstream.print(output, into: &input)
        input = transform(input)
    }
}

extension HeaderTransform: Sendable where Upstream: Sendable {}
