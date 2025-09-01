//
//  URLRouting.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 03/03/2025.
//

import ServerFoundationVapor
import Foundation
import URLRouting

// extension URLRequest {
//    /// Sets or removes the Authorization header with a Bearer token
//    /// - Parameter token: The bearer token to be used for authentication. If nil, removes the Authorization header
//    /// - Returns: A new URLRequest instance with the Authorization header set or removed
//    public mutating func setBearerToken(_ token: String?) {
//        if let token {
//            setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        } else {
//            setValue(nil, forHTTPHeaderField: "Authorization")
//        }
//    }
//    
//    /// Sets the refresh token as a cookie
//    /// - Parameter token: The refresh token to be set as a cookie. If nil, removes the refresh_token cookie
//    public mutating func setRefreshTokenCookie(_ token: String?) {
//        if let token {
//            setValue("refresh_token=\(token)", forHTTPHeaderField: "Cookie")
//        } else {
//            setValue(nil, forHTTPHeaderField: "Cookie")
//        }
//    }
// }

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
    /// Sets a cookie with the given name and value
    /// - Parameters:
    ///   - name: Cookie name
    ///   - value: Cookie value
    /// - Returns: Modified BaseURLPrinter with the cookie set
    public func cookie(_ name: String, _ value: HTTPCookies.Value) -> BaseURLPrinter<Self> {
        var requestData = URLRequestData()
        requestData.headers["cookie", default: []].append("\(name)=\(value.string)"[...])
        return self.baseRequestData(requestData)
    }

    /// Sets a cookie with the given name and optional value
    /// - Parameters:
    ///   - name: Cookie name
    ///   - value: Optional cookie value, if nil no cookie is set
    /// - Returns: Modified BaseURLPrinter with the cookie set if value exists
    public func cookie(_ name: String, _ value: HTTPCookies.Value?) -> BaseURLPrinter<Self> {
        guard let value = value
        else { return self.baseRequestData(.init()) }
        return self.cookie(name, value)
    }
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
    /// - Returns: Modified BaseURLPrinter with Reauthorization header
    public func setReauthorizationToken(_ token: String?) -> BaseURLPrinter<Self> {
        return transform { urlRequestData in
            if let token = token {
                var data = urlRequestData
                data.headers[HTTPHeaders.Name.reauthorization.description] = ["Bearer \(token)"][...].map { Substring($0) }[...]
                return data
            }
            return urlRequestData
        }
    }

    /// Sets multiple cookies at once
    /// - Parameter cookies: Dictionary mapping cookie names to values
    /// - Returns: Modified BaseURLPrinter with all cookies set
    public func cookies(_ cookies: [String: HTTPCookies.Value]) -> BaseURLPrinter<Self> {
        var requestData = URLRequestData()
        requestData.headers["cookie", default: []].append(
            cookies
                .map { name, value in "\(name)=\(value.string)" }
                .joined(separator: "; ")[...]
        )
        return self.baseRequestData(requestData)
    }
}

extension ParserPrinter where Input == URLRequestData {
    /// Transforms the URLRequestData with a provided transformation function
    /// - Parameter transform: Function that takes inout URLRequestData and returns modified URLRequestData
    /// - Returns: Modified BaseURLPrinter
    public func transform(_ transform: @escaping (inout URLRequestData) -> URLRequestData) -> BaseURLPrinter<Self> {
        var requestData = URLRequestData()
        requestData = transform(&requestData)
        return self.baseRequestData(requestData)
    }
}

extension ParserPrinter where Input == URLRequestData {
    /// Sets or removes the Bearer Authorization header
    /// - Parameter token: The bearer token to use for authentication. If nil, no change is made
    /// - Returns: Modified BaseURLPrinter with Authorization header set
    public func setBearerAuth(_ token: String?) -> BaseURLPrinter<Self> {
        transform { urlRequestData in
            if let token = token {
                var data = urlRequestData
                data.headers.authorization = ["Bearer \(token)"][...].map { Substring($0) }[...]
                return data
            }
            return urlRequestData
        }
    }
}

extension URLRequestData.Fields {
    /// Convenience accessor for the Authorization header
    public var authorization: ArraySlice<Substring?>? {
        get {
            self["Authorization"]
        }
        set {
            self["Authorization"] = newValue ?? []
        }
    }
}
