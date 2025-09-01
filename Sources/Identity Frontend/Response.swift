//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 17/02/2025.
//

import ServerFoundationVapor
import Dependencies
import Foundation

extension Vapor.Response {
    public func withTokens(
        for response: Identity.Authentication.Response
    ) -> Vapor.Response {

        self.cookies.setTokens(for: response)

        return self
    }
}

extension HTTPCookies {
    fileprivate mutating func setTokens(for response: Identity.Authentication.Response) {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        
        let accessTokenConfiguration = configuration.cookies.accessToken
        let refreshTokenConfiguration = configuration.cookies.refreshToken

        self.accessToken = .init(token: response.accessToken, configuration: accessTokenConfiguration)
        self.refreshToken = .init(token: response.refreshToken, configuration: refreshTokenConfiguration)
    }
}
