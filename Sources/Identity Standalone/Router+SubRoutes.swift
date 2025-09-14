//
//  Router+SubRoutes.swift
//  swift-identities
//
//  Helper extensions to extract sub-routers from the main Identity router
//

import Foundation
import URLRouting
import IdentitiesTypes

extension URLRouting.Router where Output == Identity.Route, Input == URLRequestData {
    
    var authentication: any URLRouting.Router<Identity.Authentication.Route> {
        self.map(
            .convert(
                apply: \.authenticate,
                unapply: Identity.Route.authenticate
            )
        )
    }
    
    var logout: any URLRouting.Router<Identity.Logout.Route> {
        self.map(
            .convert(
                apply: \.logout,
                unapply: Identity.Route.logout
            )
        )
    }
    
    var reauthorization: any URLRouting.Router<Identity.Reauthorization.Route> {
        self.map(
            .convert(
                apply: \.reauthorize,
                unapply: Identity.Route.reauthorize
            )
        )
    }
    
    var creation: any URLRouting.Router<Identity.Creation.Route> {
        self.map(
            .convert(
                apply: \.create,
                unapply: Identity.Route.create
            )
        )
    }
    
    var deletion: any URLRouting.Router<Identity.Deletion.Route> {
        self.map(
            .convert(
                apply: \.delete,
                unapply: Identity.Route.delete
            )
        )
    }
    
    var email: any URLRouting.Router<Identity.Email.Route> {
        self.map(
            .convert(
                apply: \.email,
                unapply: Identity.Route.email
            )
        )
    }
    
    // MARK: - Password Routes
    
    var password: any URLRouting.Router<Identity.Password.Route> {
        self.map(
            .convert(
                apply: \.password,
                unapply: Identity.Route.password
            )
        )
    }
}

extension URLRouting.Router where Output == Identity.Email.API, Input == URLRequestData {
    var change: any URLRouting.Router<Identity.Email.Change.API> {
        self.map(
            .convert(
                apply: \.change,
                unapply: Identity.Email.API.change
            )
        )
    }
}

extension URLRouting.Router where Output == Identity.Password.API, Input == URLRequestData {
    var change: any URLRouting.Router<Identity.Password.Change.API> {
        self.map(
            .convert(
                apply: \.change,
                unapply: Identity.Password.API.change
            )
        )
    }
    
    var reset: any URLRouting.Router<Identity.Password.Reset.API> {
        self.map(
            .convert(
                apply: \.reset,
                unapply: Identity.Password.API.reset
            )
        )
    }
}
