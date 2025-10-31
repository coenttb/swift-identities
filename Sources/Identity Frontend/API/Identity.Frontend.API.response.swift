//
//  Identity.Frontend.API.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Frontend {
    package static func response(
        api: Identity.API,
        configuration: Identity.Frontend.Configuration
    ) async throws -> any AsyncResponseEncodable {
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
    ) async throws -> any AsyncResponseEncodable {
        switch api {
        case .authenticate(let authenticate):
            return try await handleAuthenticate(authenticate, authentication: identity.authenticate, loginSuccessRedirect: redirect.loginSuccess)
        case .create(let create):
            return try await handleCreate(create, client: identity.create.client)
        case .delete(let delete):
            return try await handleDelete(delete, client: identity.delete.client, router: identity.router)
        case .email(let email):
            return try await handleEmail(email, client: identity.email.change.client)
        case .password(let password):
            return try await handlePassword(password, client: (identity.password.change.client, identity.password.reset.client))
        case .reauthorize(let reauthorize):
            return try await handleReauthorize(
                reauthorize,
                client: identity.reauthorize.client,
                router: identity.router,
                cookies: cookies
            )
        case .logout(.current):
            try await identity.logout.client.current()
            return Response.success(true)
        case .logout(.all):
            try await identity.logout.client.all()
            return Response.success(true)
        case .mfa:
            // MFA not yet implemented in Frontend
            throw Abort(.notImplemented, reason: "MFA not yet implemented in Frontend")
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
    ) async throws -> any AsyncResponseEncodable {
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
                
                return Response.json(
                    success: true,
                    data: [
                        "redirectUrl": redirectUrl.absoluteString
                    ]
                )
                    .withTokens(for: response)
            } catch let mfaRequired as Identity.Authentication.MFARequired {
                // Return MFA challenge response
                let responseData: [String: Any] = [
                    "mfaRequired": true,
                    "sessionToken": mfaRequired.sessionToken,
                    "availableMethods": mfaRequired.availableMethods.map { $0.rawValue },
                    "attemptsRemaining": mfaRequired.attemptsRemaining,
                    "expiresAt": mfaRequired.expiresAt.timeIntervalSince1970
                ]
                
                return try Response.json(success: true, data: responseData)
                
            }
            
        case .token(let token):
            switch token {
            case .access(let jwt):
                try await authentication.token.access(jwt)
                return Response.success(true)
            case .refresh(let jwt):
                let response = try await authentication.token.refresh(jwt)
                return Response.success(true)
                    .withTokens(for: response)
                    
            }
            
        case .apiKey:
            // API key authentication not yet implemented in Frontend
            throw Abort(.notImplemented, reason: "API key authentication not yet implemented")
        }
    }
    
    private static func handleCreate(
        _ create: Identity.Creation.API,
        client: Identity.Creation.Client
    ) async throws -> any AsyncResponseEncodable {
        switch create {
        case .request(let request):
            try await client.request(
                email: request.email,
                password: request.password
            )
            return Response.success(true)
            
        case .verify(let verify):
            try await client.verify(
                email: verify.email,
                token: verify.token
            )
            return Response.success(true)
        }
    }
    
    private static func handleDelete(
        _ delete: Identity.Deletion.API,
        client: Identity.Deletion.Client,
        router: any ParserPrinter<URLRequestData, Identity.Route>
    ) async throws -> any AsyncResponseEncodable {
        
        switch delete {
        case .request(let request):
            try await client.request(request.reauthToken)
            return Response.success(true)
            
        case .cancel:
            try await client.cancel()
            // Redirect to delete view with cancelled query parameter
            var deleteURL = router.url(for: .delete(.view(.request)))
            deleteURL.append(queryItems: [.init(name: "status", value: "cancelled")])
            return Response(
                status: .seeOther,
                headers: ["Location": deleteURL.absoluteString]
            )
            
        case .confirm:
            try await client.confirm()
            // Redirect to delete view with confirmed query parameter
            var deleteURL = router.url(for: .delete(.view(.request)))
            deleteURL.append(queryItems: [.init(name: "status", value: "confirmed")])
            return Response(
                status: .seeOther,
                headers: ["Location": deleteURL.absoluteString]
            )
        }
    }
    
    private static func handleEmail(
        _ email: Identity.Email.API,
        client: Identity.Email.Change.Client
    ) async throws -> any AsyncResponseEncodable {
        switch email {
        case .change(let change):
            switch change {
            case .request(let request):
                let result = try await client.request(request.newEmail)
                switch result {
                case .success:
                    return Response.success(true)
                case .requiresReauthentication:
                    return Response(
                        status: .unauthorized,
                        headers: ["X-Requires-Reauth": "true"],
                        body: .init(string: "Reauthorization required")
                    )
                }
                
            case .confirm(let confirm):
                let authResponse = try await client.confirm(confirm.token)
                // Return success with new tokens (email has changed, so tokens need updating)
                return Response.success(true)
                    .withTokens(for: authResponse)
            }
        }
    }
    
    private static func handlePassword(
        _ password: Identity.Password.API,
        client: (change: Identity.Password.Change.Client, reset: Identity.Password.Reset.Client)
    ) async throws -> any AsyncResponseEncodable {
        switch password {
        case .reset(let reset):
            switch reset {
            case .request(let request):
                try await client.reset.request(request.email)
                return Response.success(true)
                
            case .confirm(let confirm):
                try await client.reset.confirm(
                    newPassword: confirm.newPassword,
                    token: confirm.token
                )
                return Response.success(true)
            }
            
        case .change(let change):
            switch change {
            case .request(change: let request):
                try await client.change.request(
                    currentPassword: request.currentPassword,
                    newPassword: request.newPassword
                )
                return Response.success(true)
            }
        }
    }
    
    private static func handleReauthorize(
        _ reauthorize: Identity.Reauthorization.API,
        client: Identity.Reauthorization.Client,
        router: any ParserPrinter<URLRequestData, Identity.Route>,
        cookies: Identity.Frontend.Configuration.Cookies
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(\.request) var request
        
        let jwt = try await client.reauthorize(reauthorize.password)
        
        // Set reauthorization cookie
        let cookieValue = HTTPCookies.Value(
            string: try jwt.compactSerialization(),
            expires: Date(timeIntervalSinceNow: TimeInterval(cookies.reauthorizationToken.expires)),
            maxAge: Int(cookies.reauthorizationToken.expires),
            domain: cookies.reauthorizationToken.domain,
            path: cookies.reauthorizationToken.path,
            isSecure: cookies.reauthorizationToken.isSecure,
            isHTTPOnly: cookies.reauthorizationToken.isHTTPOnly,
            sameSite: cookies.reauthorizationToken.sameSitePolicy
        )
        
        // Check if this is an AJAX request
        if request?.headers["Accept"].first?.contains("application/json") == true {
            // Return JSON response for AJAX requests with the token
            let response = Response.success(true, data: ["token": try jwt.compactSerialization()])
            response.cookies["reauthorization_token"] = cookieValue
            return response
        } else {
            // For regular form submissions, redirect to the email change page
            let response = Response(
                status: .seeOther,
                headers: ["Location": router.url(for: .email(.view(.change(.request)))).absoluteString]
            )
            response.cookies["reauthorization_token"] = cookieValue
            return response
        }
        
    }
    
    private static func handleOAuth(
        _ oauth: Identity.OAuth.API,
        client: Identity.OAuth.Client?
    ) async throws -> any AsyncResponseEncodable {
        guard let client else {
            throw Abort(.notImplemented, reason: "OAuth not configured")
        }
        
        switch oauth {
        case .providers:
            // Return list of available OAuth providers
            let providers = try await client.providers()
            let providerData = providers.map { provider in
                ["id": provider.identifier, "name": provider.displayName]
            }
            return Response.json(success: true, data: providerData)
            
        case .authorize(let providerName):
            // Generate authorization URL and redirect
            @Dependency(\.request) var request
            guard let request else { throw Abort.requestUnavailable }
            
            // Build redirect URI from current request
            let scheme = request.headers.first(name: "X-Forwarded-Proto") ?? "http"
            let host = request.headers.first(name: .host) ?? "localhost"
            let redirectURI = "\(scheme)://\(host)/api/oauth/callback"
            
            let authURL = try await client.authorizationURL(
                providerName,
                redirectURI
            )
            return Response(status: .seeOther, headers: ["Location": authURL.absoluteString])
            
        case .callback(let credentials):
            // Handle OAuth callback
            let authResponse = try await client.callback(credentials)
            
            @Dependency(Identity.Frontend.Configuration.self) var config
            let cookies = config.cookies
            
            // Set authentication cookies
            let accessCookieValue = HTTPCookies.Value(
                string: authResponse.accessToken,
                expires: Date(timeIntervalSinceNow: TimeInterval(cookies.accessToken.expires)),
                maxAge: Int(cookies.accessToken.expires),
                domain: cookies.accessToken.domain,
                path: cookies.accessToken.path,
                isSecure: cookies.accessToken.isSecure,
                isHTTPOnly: cookies.accessToken.isHTTPOnly,
                sameSite: cookies.accessToken.sameSitePolicy
            )
            
            let refreshCookieValue = HTTPCookies.Value(
                string: authResponse.refreshToken,
                expires: Date(timeIntervalSinceNow: TimeInterval(cookies.refreshToken.expires)),
                maxAge: Int(cookies.refreshToken.expires),
                domain: cookies.refreshToken.domain,
                path: cookies.refreshToken.path,
                isSecure: cookies.refreshToken.isSecure,
                isHTTPOnly: cookies.refreshToken.isHTTPOnly,
                sameSite: cookies.refreshToken.sameSitePolicy
            )
            
            let jwt = try JWT.parse(from: authResponse.accessToken)
            let accessToken = try Identity.Token.Access(jwt: jwt)
            let identityId = accessToken.identityId
            
            let response = try await Response(
                status: .seeOther,
                headers: ["Location": "\(config.redirect.loginSuccess(identityId))"] // Or redirect to intended destination
            )
            response.cookies[Identity.Cookies.Names.accessToken] = accessCookieValue
            response.cookies[Identity.Cookies.Names.refreshToken] = refreshCookieValue
            return response
            
        case .connections:
            // Get OAuth connections for current user
            let connections = try await client.getAllConnections()
            return Response.json(success: true, data: connections)
            
        case .disconnect(let providerName):
            // Disconnect OAuth provider
            try await client.disconnect(providerName)
            return Response.success(true)
        }
    }
}
