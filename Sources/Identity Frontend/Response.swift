//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 17/02/2025.
//

import Dependencies
import Foundation
import HTTP_Cookies
import IdentitiesTypes
import Server_Vapor

import enum Server.Server

extension Server.Response {
    /// A copy of this response carrying `Set-Cookie` lines for the
    /// authentication token pair, under the frontend cookie configuration.
    package func withTokens(
        for response: Identity.Authentication.Response
    ) -> Server.Response {
        @Dependency(\.identityFrontendConfiguration) var configuration

        return
            self
            .setting(
                cookie: Identity.Cookies.Names.accessToken,
                token: response.accessToken,
                configuration: configuration.cookies.accessToken
            )
            .setting(
                cookie: Identity.Cookies.Names.refreshToken,
                token: response.refreshToken,
                configuration: configuration.cookies.refreshToken
            )
    }
}
