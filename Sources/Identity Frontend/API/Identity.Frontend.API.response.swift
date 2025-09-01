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
            client: configuration.client,
            router: configuration.router,
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
        client: Identity.Client,
        router: AnyParserPrinter<URLRequestData, Identity.Route>,
        cookies: Identity.Frontend.Configuration.Cookies,
        redirect: Identity.Frontend.Configuration.Redirect
    ) async throws -> any AsyncResponseEncodable {
        switch api {
        case .authenticate(let authenticate):
            return try await handleAuthenticate(authenticate, client: client, loginSuccessRedirect: redirect.loginSuccess)
        case .create(let create):
            return try await handleCreate(create, client: client)
        case .delete(let delete):
            return try await handleDelete(delete, client: client, router: router)
        case .email(let email):
            return try await handleEmail(email, client: client)
        case .password(let password):
            return try await handlePassword(password, client: client)
        case .reauthorize(let reauthorize):
            return try await handleReauthorize(
                reauthorize,
                client: client,
                router: router,
                cookies: cookies
            )
        case .logout(.current):
            try await client.logout.current()
            return Response.success(true)
        case .logout(.all):
            try await client.logout.all()
            return Response.success(true)
        case .mfa:
            // MFA not yet implemented in Frontend
            throw Abort(.notImplemented, reason: "MFA not yet implemented in Frontend")
        }
    }
    
    private static func handleAuthenticate(
        _ authenticate: Identity.API.Authenticate,
        client: Identity.Client,
        loginSuccessRedirect: (UUID) async throws -> URL
    ) async throws -> any AsyncResponseEncodable {
        switch authenticate {
        case .credentials(let credentials):
            do {
                let response = try await client.authenticate.credentials(
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
                try await client.authenticate.token.access(jwt)
                return Response.success(true)
            case .refresh(let jwt):
                let response = try await client.authenticate.token.refresh(jwt)
                return Response.success(true)
                    .withTokens(for: response)
                    
            }
            
        case .apiKey(let apiKey):
            // API key authentication not yet implemented in Frontend
            throw Abort(.notImplemented, reason: "API key authentication not yet implemented")
        }
    }
    
    private static func handleCreate(
        _ create: Identity.API.Create,
        client: Identity.Client
    ) async throws -> any AsyncResponseEncodable {
        switch create {
        case .request(let request):
            try await client.create.request(
                email: request.email,
                password: request.password
            )
            return Response.success(true)
            
        case .verify(let verify):
            try await client.create.verify(
                email: verify.email,
                token: verify.token
            )
            return Response.success(true)
        }
    }
    
    private static func handleDelete(
        _ delete: Identity.API.Delete,
        client: Identity.Client,
        router: AnyParserPrinter<URLRequestData, Identity.Route>
    ) async throws -> any AsyncResponseEncodable {
        
        switch delete {
        case .request(let request):
            try await client.delete.request(request.reauthToken)
            return Response.success(true)
            
        case .cancel:
            try await client.delete.cancel()
            // Redirect to delete view with cancelled query parameter
            var deleteURL = router.url(for: .delete(.view(.request)))
            deleteURL.append(queryItems: [.init(name: "status", value: "cancelled")])
            return Response(
                status: .seeOther,
                headers: ["Location": deleteURL.absoluteString]
            )
            
        case .confirm:
            try await client.delete.confirm()
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
        _ email: Identity.API.Email,
        client: Identity.Client
    ) async throws -> any AsyncResponseEncodable {
        switch email {
        case .change(let change):
            switch change {
            case .request(let request):
                let result = try await client.email.change.request(request.newEmail)
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
                let authResponse = try await client.email.change.confirm(confirm.token)
                // Return success with new tokens (email has changed, so tokens need updating)
                return Response.success(true)
                    .withTokens(for: authResponse)
            }
        }
    }
    
    private static func handlePassword(
        _ password: Identity.API.Password,
        client: Identity.Client
    ) async throws -> any AsyncResponseEncodable {
        switch password {
        case .reset(let reset):
            switch reset {
            case .request(let request):
                try await client.password.reset.request(request.email)
                return Response.success(true)
                
            case .confirm(let confirm):
                try await client.password.reset.confirm(
                    newPassword: confirm.newPassword,
                    token: confirm.token
                )
                return Response.success(true)
            }
            
        case .change(let change):
            switch change {
            case .request(change: let request):
                try await client.password.change.request(
                    currentPassword: request.currentPassword,
                    newPassword: request.newPassword
                )
                return Response.success(true)
            }
        }
    }
    
    private static func handleReauthorize(
        _ reauthorize: Identity.API.Reauthorize,
        client: Identity.Client,
        router: AnyParserPrinter<URLRequestData, Identity.Route>,
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
}
