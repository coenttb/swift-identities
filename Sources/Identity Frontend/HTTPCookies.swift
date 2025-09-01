//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 11/02/2025.
//

import ServerFoundationVapor
import Foundation

extension HTTPCookies {
    public var accessToken: HTTPCookies.Value? {
        get {
            self["access_token"]
        }
        set {
            self["access_token"] = newValue
        }
    }

    public var refreshToken: HTTPCookies.Value? {
        get {
            self["refresh_token"]
        }
        set {
            self["refresh_token"] = newValue
        }
    }

    public var reauthorizationToken: HTTPCookies.Value? {
        get {
            self["reauthorization_token"]
        }
        set {
            self["reauthorization_token"] = newValue
        }
    }
}

extension [WritableKeyPath<HTTPCookies, HTTPCookies.Value?>] {
    public static let identity: Self = [
        \.accessToken,
        \.refreshToken,
        \.reauthorizationToken
    ]
}
