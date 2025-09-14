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

    // MARK: - Authentication Routes

    var authentication: any URLRouting.Router<Identity.Authentication.Route> {
        self.map(
            .convert(
                apply: \.authenticate,
                unapply: Identity.Route.authenticate
            )
        )
    }

    // MARK: - Logout Routes

    var logout: any URLRouting.Router<Identity.Logout.Route> {
        self.map(
            .convert(
                apply: \.logout,
                unapply: Identity.Route.logout
            )
        )
    }

    // MARK: - Reauthorization Routes

//    var reauthorization: any URLRouting.Router<Identity.Reauthorization.Request> {
//        self.map(
//            .convert(
//                apply: \.reauthorize,
//                unapply: Identity.Route.reauthorize
//            )
//        )
//    }

    // MARK: - Creation Routes

    var creation: any URLRouting.Router<Identity.Creation.Route> {
        self.map(
            .convert(
                apply: \.create,
                unapply: Identity.Route.create
            )
        )
    }

    // MARK: - Deletion Routes

    var deletion: any URLRouting.Router<Identity.Deletion.Route> {
        self.map(
            .convert(
                apply: \.delete,
                unapply: Identity.Route.delete
            )
        )
    }

    // MARK: - Email Routes
//
//    var email: any URLRouting.Router<Identity.Email.Route> {
//        self.map(
//            .convert(
//                apply: \.email,
//                unapply: Identity.Route.email
//            )
//        )
//    }
//
//    var emailChange: any URLRouting.Router<Identity.Email.Change.API> {
//        self.map(
//            .convert(
//                apply: \.email.change,
//                unapply: Identity.Route.email.change
//            )
//        )
//    }

    // MARK: - Password Routes

    var password: any URLRouting.Router<Identity.Password.Route> {
        self.map(
            .convert(
                apply: \.password,
                unapply: Identity.Route.password
            )
        )
    }

//    var passwordChange: any URLRouting.Router<Identity.Password.Change.API> {
//        self.map(
//            .convert(
//                apply: \.password.change,
//                unapply: Identity.Route.password.change
//            )
//        )
//    }
//
//    var passwordReset: any URLRouting.Router<Identity.Password.Reset.API> {
//        self.map(
//            .convert(
//                apply: \.password.reset,
//                unapply: Identity.Route.password.reset
//            )
//        )
//    }
}
