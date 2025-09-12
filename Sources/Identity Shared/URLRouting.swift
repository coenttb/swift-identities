//
//  URLRouting.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 03/03/2025.
//

import ServerFoundationVapor
import Foundation
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
