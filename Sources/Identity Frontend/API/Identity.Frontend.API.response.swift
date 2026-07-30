//
//  Identity.Frontend.API.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Dependencies
import Foundation
import HTTP_Cookies
import HTTP_Standard
import IdentitiesTypes
import Server_Vapor
import Vapor

import enum Server.Server

extension Identity.Frontend {
    package static func response(
        api: Identity.API,
        configuration: Identity.Frontend.Configuration
    ) async throws -> Server.Response {
        return try await Self.response(
            api: api,
            identity: configuration.identity,
            cookies: configuration.cookies,
            redirect: configuration.redirect
        )
    }

    /// Handles API requests using the configuration's client.
    ///
    /// This function provides the shared API response logic used by both
    /// Consumer and Standalone.
    package static func response(
        api: Identity.API,
        identity: Identity,
        cookies: Identity.Frontend.Configuration.Cookies,
        redirect: Identity.Frontend.Configuration.Redirect
    ) async throws -> Server.Response {
        switch api {
        case .authenticate(let authenticate):
            return try await handleAuthenticate(
                authenticate,
                authentication: identity.authenticate,
                loginSuccessRedirect: redirect.loginSuccess
            )
        case .create(let create):
            return try await handleCreate(create, client: identity.create.client)
        case .delete(let delete):
            return try await handleDelete(
                delete,
                client: identity.delete.client,
                router: identity.router
            )
        case .email(let email):
            return try await handleEmail(email, client: identity.email.change.client)
        case .password(let password):
            return try await handlePassword(
                password,
                client: (identity.password.change.client, identity.password.reset.client)
            )
        case .reauthorize(let reauthorize):
            return try await handleReauthorize(
                reauthorize,
                client: identity.reauthorize.client,
                router: identity.router,
                cookies: cookies
            )
        case .logout(.current):
            try await identity.logout.client.current()
            return try Server.Response.json(success: true)
        case .logout(.all):
            try await identity.logout.client.all()
            return try Server.Response.json(success: true)
        case .mfa:
            // MFA not yet implemented in Frontend
            throw Server.Error.notImplemented("MFA not yet implemented in Frontend")
        case .oauth(let oauth):
            return try await handleOAuth(
                oauth,
                client: identity.oauth?.client
            )
        }
    }

    private static func handleAuthenticate(
        _ authenticate: Identity.Authentication.API,
        authentication: Identity.Authentication,
        loginSuccessRedirect: (Identity.ID) async throws -> URL
    ) async throws -> Server.Response {
        switch authenticate {
        case .credentials(let credentials):
            do {
                let response = try await authentication.client.credentials(
                    username: credentials.username,
                    password: credentials.password
                )

                let jwt = try JWT.parse(from: response.accessToken)
                let accessToken = try Identity.Token.Access(jwt: jwt)
                let identityId = accessToken.identityId

                let redirectUrl = try await loginSuccessRedirect(identityId)

                return try Server.Response.json(
                    success: true,
                    data: [
                        "redirectUrl": redirectUrl.absoluteString
                    ]
                )
                .withTokens(for: response)
            } catch let mfaRequired as Identity.Authentication.MFARequired {
                // Return MFA challenge response
                struct MFAChallenge: Encodable {
                    let mfaRequired: Bool
                    let sessionToken: String
                    let availableMethods: [String]
                    let attemptsRemaining: Int
                    let expiresAt: Double
                }

                return try Server.Response.json(
                    success: true,
                    data: MFAChallenge(
                        mfaRequired: true,
                        sessionToken: mfaRequired.sessionToken,
                        availableMethods: mfaRequired.availableMethods.map { $0.rawValue },
                        attemptsRemaining: mfaRequired.attemptsRemaining,
                        expiresAt: mfaRequired.expiresAt.timeIntervalSince1970
                    )
                )
            }

        case .token(let token):
            switch token {
            case .access(let jwt):
                try await authentication.token.access(jwt)
                return try Server.Response.json(success: true)
            case .refresh(let jwt):
                let response = try await authentication.token.refresh(jwt)
                return try Server.Response.json(success: true)
                    .withTokens(for: response)

            }

        case .apiKey:
            // API key authentication not yet implemented in Frontend
            throw Server.Error.notImplemented("API key authentication not yet implemented")
        }
    }

    private static func handleCreate(
        _ create: Identity.Creation.API,
        client: Identity.Creation.Client
    ) async throws -> Server.Response {
        switch create {
        case .request(let request):
            try await client.request(
                email: request.email,
                password: request.password
            )
            return try Server.Response.json(success: true)

        case .verify(let verify):
            try await client.verify(
                email: verify.email,
                token: verify.token
            )
            return try Server.Response.json(success: true)
        }
    }

    private static func handleDelete(
        _ delete: Identity.Deletion.API,
        client: Identity.Deletion.Client,
        router: any ParserPrinter<URLRequestData, Identity.Route>
    ) async throws -> Server.Response {

        switch delete {
        case .request(let request):
            try await client.request(request.reauthToken)
            return try Server.Response.json(success: true)

        case .cancel:
            try await client.cancel()
            // Redirect to delete view with cancelled query parameter
            var deleteURL = router.url(for: .delete(.view(.request)))
            deleteURL.append(queryItems: [.init(name: "status", value: "cancelled")])
            return Server.Response.redirect(to: deleteURL.absoluteString)

        case .confirm:
            try await client.confirm()
            // Redirect to delete view with confirmed query parameter
            var deleteURL = router.url(for: .delete(.view(.request)))
            deleteURL.append(queryItems: [.init(name: "status", value: "confirmed")])
            return Server.Response.redirect(to: deleteURL.absoluteString)
        }
    }

    private static func handleEmail(
        _ email: Identity.Email.API,
        client: Identity.Email.Change.Client
    ) async throws -> Server.Response {
        switch email {
        case .change(let change):
            switch change {
            case .request(let request):
                let result = try await client.request(request.newEmail)
                switch result {
                case .success:
                    return try Server.Response.json(success: true)
                case .requiresReauthentication:
                    return Server.Response(
                        status: .unauthorized,
                        headers: HTTP.Headers([try .init(name: "X-Requires-Reauth", value: "true")]),
                        body: Array("Reauthorization required".utf8)
                    )
                }

            case .confirm(let confirm):
                let authResponse = try await client.confirm(confirm.token)
                // Return success with new tokens (email has changed, so tokens need updating)
                return try Server.Response.json(success: true)
                    .withTokens(for: authResponse)
            }
        }
    }

    private static func handlePassword(
        _ password: Identity.Password.API,
        client: (change: Identity.Password.Change.Client, reset: Identity.Password.Reset.Client)
    ) async throws -> Server.Response {
        switch password {
        case .reset(let reset):
            switch reset {
            case .request(let request):
                try await client.reset.request(request.email)
                return try Server.Response.json(success: true)

            case .confirm(let confirm):
                try await client.reset.confirm(
                    newPassword: confirm.newPassword,
                    token: confirm.token
                )
                return try Server.Response.json(success: true)
            }

        case .change(let change):
            switch change {
            case .request(change: let request):
                try await client.change.request(
                    currentPassword: request.currentPassword,
                    newPassword: request.newPassword
                )
                return try Server.Response.json(success: true)
            }
        }
    }

    private static func handleReauthorize(
        _ reauthorize: Identity.Reauthorization.API,
        client: Identity.Reauthorization.Client,
        router: any ParserPrinter<URLRequestData, Identity.Route>,
        cookies: Identity.Frontend.Configuration.Cookies
    ) async throws -> Server.Response {
        @Dependency(\.vapor.request) var request

        let jwt = try await client.reauthorize(reauthorize.password)
        let token = try jwt.compactSerialization()

        // Check if this is an AJAX request
        if request?.headers["Accept"].first?.contains("application/json") == true {
            // Return JSON response for AJAX requests with the token
            return try Server.Response.json(success: true, data: ["token": token])
                .setting(
                    cookie: Identity.Cookies.Names.reauthorizationToken,
                    token: token,
                    configuration: cookies.reauthorizationToken
                )
        } else {
            // For regular form submissions, redirect to the email change page
            return Server.Response.redirect(
                to: router.url(for: .email(.view(.change(.request)))).absoluteString
            )
            .setting(
                cookie: Identity.Cookies.Names.reauthorizationToken,
                token: token,
                configuration: cookies.reauthorizationToken
            )
        }

    }

    private static func handleOAuth(
        _ oauth: Identity.OAuth.API,
        client: Identity.OAuth.Client?
    ) async throws -> Server.Response {
        guard let client else {
            throw Server.Error.notImplemented("OAuth not configured")
        }

        switch oauth {
        case .providers:
            // Return list of available OAuth providers
            let providers = try await client.providers()
            let providerData = providers.map { provider in
                ["id": provider.identifier, "name": provider.displayName]
            }
            return try Server.Response.json(success: true, data: providerData)

        case .authorize(let providerName):
            // Generate authorization URL and redirect
            @Dependency(\.vapor.request) var request
            guard let request else {
                throw Server.Error.internalError("Request is unavailable")
            }

            // Build redirect URI from current request
            let scheme = request.headers.first(name: "X-Forwarded-Proto") ?? "http"
            let host = request.headers.first(name: .host) ?? "localhost"
            let redirectURI = "\(scheme)://\(host)/api/oauth/callback"

            let authURL = try await client.authorizationURL(
                providerName,
                redirectURI
            )
            return Server.Response.redirect(to: authURL.absoluteString)

        case .callback(let credentials):
            // Handle OAuth callback
            let authResponse = try await client.callback(credentials)

            @Dependency(\.identityFrontendConfiguration) var config

            let jwt = try JWT.parse(from: authResponse.accessToken)
            let accessToken = try Identity.Token.Access(jwt: jwt)
            let identityId = accessToken.identityId

            return Server.Response.redirect(
                to: "\(try await config.redirect.loginSuccess(identityId))"
            )
            .withTokens(for: authResponse)

        case .connections:
            // Get OAuth connections for current user
            let connections = try await client.getAllConnections()
            return try Server.Response.json(success: true, data: connections)

        case .disconnect(let providerName):
            // Disconnect OAuth provider
            try await client.disconnect(providerName)
            return try Server.Response.json(success: true)
        }
    }
}
