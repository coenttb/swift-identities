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
    ) throws -> AnyParserPrinter<URLRequestData, Identity.Consumer.API> {
        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }

        @Dependency(\.identity.provider.router) var router

        switch route {
        case .authenticate(let authenticate):
            switch authenticate {
            case .credentials:
                break

            case .token:
                return router
                    .setBearerAuth(request.cookies.accessToken?.string)
                    .eraseToAnyParserPrinter()
            case .apiKey:
                break

            }

        case .email:
            return router
                .setBearerAuth(request.cookies.accessToken?.string)
                .setReauthorizationToken(request.cookies.reauthorizationToken?.string)
                .eraseToAnyParserPrinter()

        case .password(let password):
            switch password {
            case .reset:
                break

            case .change:
                return router
                    .setBearerAuth(request.cookies.accessToken?.string)
                    .eraseToAnyParserPrinter()
            }

        case .create, .delete, .logout, .reauthorize:
            return router
                .setBearerAuth(request.cookies.accessToken?.string)
                .eraseToAnyParserPrinter()
            
        case .mfa(_):
            break
        }

        return router.eraseToAnyParserPrinter()
    }
}

extension AnyParserPrinter<URLRequestData, Identity.API> {
    package func configureAuthentication(for route: Identity.API) throws -> Self {
        try Identity.Consumer.API.Router.configureAuthentication(baseRouter: self, route: route)
    }
}
