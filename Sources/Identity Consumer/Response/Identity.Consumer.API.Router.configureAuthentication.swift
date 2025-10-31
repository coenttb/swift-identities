//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 13/02/2025.
//

import Identity_Shared
import ServerFoundationVapor
import IdentitiesTypes

extension Identity.Consumer.API.Router {
    package static func configureAuthentication(
        baseRouter: some URLRouting.Router<Identity.Consumer.API>,
        route: Identity.Consumer.API
    ) throws -> any ParserPrinter<URLRequestData, Identity.Consumer.API> {
        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }

        @Dependency(Identity.Consumer.Configuration.self) var configuration
        let router = configuration.provider.router

        switch route {
        case .authenticate(let authenticate):
            switch authenticate {
            case .credentials:
                break

            case .token:
                return router
                    .setBearerAuth(request.cookies.accessToken?.string)
                    
            case .apiKey:
                break

            }

        case .email:
            return router
                .setBearerAuth(request.cookies.accessToken?.string)
                .setReauthorizationToken(request.cookies.reauthorizationToken?.string)
                
        case .password(let password):
            switch password {
            case .reset:
                break

            case .change:
                return router
                    .setBearerAuth(request.cookies.accessToken?.string)
            }

        case .create, .delete, .logout, .reauthorize:
            return router
                .setBearerAuth(request.cookies.accessToken?.string)
                
            
        case .mfa(_):
            break
        case .oauth(let oauth):
            // OAuth views generally don't require authentication
            // except for the connections management page
            switch oauth {
            case .connections, .disconnect:
                // Managing OAuth connections requires authentication
                return router
                    .setBearerAuth(request.cookies.accessToken?.string)
            case .providers, .authorize, .callback:
                // These are part of the OAuth flow and don't require authentication
                break
            }
        }

        return router
    }
}

extension ParserPrinter<URLRequestData, Identity.API> {
    package func configureAuthentication(for route: Identity.API) throws -> any ParserPrinter<URLRequestData, Identity.API> {
        try Identity.Consumer.API.Router.configureAuthentication(baseRouter: self, route: route)
    }
}
