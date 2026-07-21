//
//  Identity Route Router Parity Tests.swift
//  swift-authentication
//
//  Batch-0 corpus over `Identity.Route.Router()` — the unified API+View router
//  the Consumer configuration vends (and wraps with a base URL in production;
//  the `.baseURL`-composed corpus mirrors that shape with a FIXED base URL).
//  View leaves are covered exhaustively; API nesting is exercised with one
//  representative route per domain (API leaves are exhaustively covered by the
//  `Identity.API.Router` corpus).
//

import Foundation
import IdentitiesTypes
import Testing
import URL_Routing_Test_Support

@Suite("Identity Route Router Parity")
struct IdentityRouteRouterParityTests {

    static func routes() throws -> [(name: String, route: Identity.Route)] { [
        // API nesting — one representative per domain
        ("api.authenticate.credentials", .authenticate(.api(.credentials(.init(username: Fixed.email, password: Fixed.password))))),
        ("api.create.request", .create(.api(.request(.init(email: Fixed.email, password: Fixed.password))))),
        ("api.delete.request", .delete(.api(.request(.init(reauthToken: Fixed.reauthToken))))),
        ("api.email.change.request", .email(.api(.change(.request(.init(newEmail: Fixed.newEmail)))))),
        ("api.password.reset.request", .password(.api(.reset(.request(.init(email: Fixed.email)))))),
        ("api.mfa.verify", .mfa(.api(.verify(.init(sessionToken: Fixed.sessionToken, method: .totp, code: Fixed.code))))),
        ("api.logout.current", .logout(.api(.current))),
        ("api.reauthorize", .reauthorize(.api(.init(password: Fixed.password)))),
        ("api.oauth.providers", .oauth(.api(.providers))),
        // Views — exhaustive leaves
        ("view.authenticate.credentials", .authenticate(.view(.credentials))),
        ("view.create.request", .create(.view(.request))),
        ("view.create.verify", .create(.view(.verify(.init(token: Fixed.token, email: Fixed.email))))),
        ("view.delete.request", .delete(.view(.request))),
        ("view.logout", .logout(.view)),
        ("view.email.change.request", .email(.view(.change(.request)))),
        ("view.email.change.confirm", .email(.view(.change(.confirm(.init(token: Fixed.token)))))),
        ("view.email.change.reauthorization", .email(.view(.change(.reauthorization)))),
        ("view.password.reset.request", .password(.view(.reset(.request)))),
        ("view.password.reset.confirm", .password(.view(.reset(.confirm(.init(token: Fixed.token, newPassword: Fixed.password)))))),
        ("view.password.change.request", .password(.view(.change(.request)))),
        ("view.mfa.verify", .mfa(.view(.verify(.init(sessionToken: Fixed.sessionToken, attemptsRemaining: 3))))),
        ("view.mfa.manage", .mfa(.view(.manage))),
        ("view.mfa.totp.setup", .mfa(.view(.totp(.setup)))),
        ("view.mfa.totp.confirmSetup", .mfa(.view(.totp(.confirmSetup)))),
        ("view.mfa.totp.manage", .mfa(.view(.totp(.manage)))),
        ("view.mfa.backupCodes.display", .mfa(.view(.backupCodes(.display)))),
        ("view.mfa.backupCodes.verify", .mfa(.view(.backupCodes(.verify(.init(sessionToken: Fixed.sessionToken, attemptsRemaining: 3)))))),
        ("view.oauth.login", .oauth(.view(.login))),
        ("view.oauth.callback", .oauth(.view(.callback(.init(provider: Fixed.provider, code: Fixed.code, state: Fixed.state))))),
        ("view.oauth.connections", .oauth(.view(.connections))),
        ("view.oauth.error", .oauth(.view(.error("access_denied"))))
    ] }

    @Test("Identity.Route.Router corpus")
    func routeRouterCorpus() throws {
        let corpus = try Parity.corpus(of: try Self.routes(), via: Identity.Route.Router())
        try assertParity(corpus, fixture: "identity-route-router")
    }

    @Test("Identity.Route.Router baseURL-composed corpus")
    func routeRouterBaseURLCorpus() throws {
        let router = Identity.Route.Router().baseURL(Fixed.baseURL)
        let corpus = try Parity.corpus(of: try Self.routes(), via: router)
        try assertParity(corpus, fixture: "identity-route-router-baseurl")
    }

    @Test("Identity.Route.Router round-trips")
    func routeRouterRoundTrips() throws {
        var failures: [String] = []
        let router = Identity.Route.Router()
        for (name, route) in try Self.routes() {
            do {
                if try !Parity.roundTrips(route, via: router) {
                    failures.append("\(name): parse(print(route)) != route")
                }
            } catch {
                failures.append("\(name): \(error)")
            }
        }
        try recordNonRoundTrips(failures, fixture: "identity-route-router")
    }
}
