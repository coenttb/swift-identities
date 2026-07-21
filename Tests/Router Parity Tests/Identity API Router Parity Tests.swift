//
//  Identity API Router Parity Tests.swift
//  swift-authentication
//
//  Batch-0 corpus over `Identity.API.Router()` — the router the Provider and
//  Consumer configurations vend (erased to `AnyParserPrinter`). Every
//  constructible leaf is printed with fixed values; body routes all covered.
//

import Foundation
import IdentitiesTypes
import Testing
import URL_Routing_Test_Support

@Suite("Identity API Router Parity")
struct IdentityAPIRouterParityTests {

    static func routes() throws -> [(name: String, route: Identity.API)] { [
        // Authentication
        ("authenticate.credentials", .authenticate(.credentials(.init(username: Fixed.email, password: Fixed.password)))),
        ("authenticate.token.access", .authenticate(.token(.access(Fixed.jwt)))),
        ("authenticate.token.refresh", .authenticate(.token(.refresh(Fixed.jwt)))),
        ("authenticate.apiKey", .authenticate(.apiKey(try .init(token: Fixed.token)))),
        // Reauthorization
        ("reauthorize", .reauthorize(.init(password: Fixed.password))),
        // Creation
        ("create.request", .create(.request(.init(email: Fixed.email, password: Fixed.password)))),
        ("create.verify", .create(.verify(.init(token: Fixed.token, email: Fixed.email)))),
        // Deletion
        ("delete.request", .delete(.request(.init(reauthToken: Fixed.reauthToken)))),
        ("delete.cancel", .delete(.cancel)),
        ("delete.confirm", .delete(.confirm)),
        // Logout
        ("logout.current", .logout(.current)),
        ("logout.all", .logout(.all)),
        // Email change
        ("email.change.request", .email(.change(.request(.init(newEmail: Fixed.newEmail))))),
        ("email.change.confirm", .email(.change(.confirm(.init(token: Fixed.token))))),
        // Password
        ("password.reset.request", .password(.reset(.request(.init(email: Fixed.email))))),
        ("password.reset.confirm", .password(.reset(.confirm(.init(token: Fixed.token, newPassword: Fixed.password))))),
        ("password.change.request", .password(.change(.request(.init(currentPassword: Fixed.password, newPassword: Fixed.password))))),
        // MFA — TOTP
        ("mfa.totp.setup", .mfa(.totp(.setup))),
        ("mfa.totp.confirmSetup", .mfa(.totp(.confirmSetup(.init(code: Fixed.code))))),
        ("mfa.totp.verify", .mfa(.totp(.verify(.init(code: Fixed.code, sessionToken: Fixed.sessionToken))))),
        ("mfa.totp.disable", .mfa(.totp(.disable(.init(reauthorizationToken: Fixed.reauthToken))))),
        // MFA — SMS
        ("mfa.sms.setup", .mfa(.sms(.setup(.init(phoneNumber: Fixed.phoneNumber))))),
        ("mfa.sms.requestCode", .mfa(.sms(.requestCode))),
        ("mfa.sms.verify", .mfa(.sms(.verify(.init(code: Fixed.code, sessionToken: Fixed.sessionToken))))),
        ("mfa.sms.updatePhoneNumber", .mfa(.sms(.updatePhoneNumber(.init(phoneNumber: Fixed.phoneNumber, reauthorizationToken: Fixed.reauthToken))))),
        ("mfa.sms.disable", .mfa(.sms(.disable(.init(reauthorizationToken: Fixed.reauthToken))))),
        // MFA — Email
        ("mfa.email.setup", .mfa(.email(.setup(.init(email: Fixed.email))))),
        ("mfa.email.requestCode", .mfa(.email(.requestCode))),
        ("mfa.email.verify", .mfa(.email(.verify(.init(code: Fixed.code, sessionToken: Fixed.sessionToken))))),
        ("mfa.email.updateEmail", .mfa(.email(.updateEmail(.init(email: Fixed.newEmail, reauthorizationToken: Fixed.reauthToken))))),
        ("mfa.email.disable", .mfa(.email(.disable(.init(reauthorizationToken: Fixed.reauthToken))))),
        // MFA — WebAuthn
        ("mfa.webauthn.beginRegistration", .mfa(.webauthn(.beginRegistration))),
        ("mfa.webauthn.finishRegistration", .mfa(.webauthn(.finishRegistration(.init(credentialName: "parity-key", response: "{\"fixed\":true}"))))),
        ("mfa.webauthn.beginAuthentication", .mfa(.webauthn(.beginAuthentication))),
        ("mfa.webauthn.finishAuthentication", .mfa(.webauthn(.finishAuthentication(.init(response: "{\"fixed\":true}", sessionToken: Fixed.sessionToken))))),
        ("mfa.webauthn.listCredentials", .mfa(.webauthn(.listCredentials))),
        ("mfa.webauthn.removeCredential", .mfa(.webauthn(.removeCredential(.init(credentialId: "fixed-credential-id", reauthorizationToken: Fixed.reauthToken))))),
        ("mfa.webauthn.disable", .mfa(.webauthn(.disable(.init(reauthorizationToken: Fixed.reauthToken))))),
        // MFA — Backup codes
        ("mfa.backupCodes.regenerate", .mfa(.backupCodes(.regenerate))),
        ("mfa.backupCodes.verify", .mfa(.backupCodes(.verify(.init(code: Fixed.code, sessionToken: Fixed.sessionToken))))),
        ("mfa.backupCodes.remaining", .mfa(.backupCodes(.remaining))),
        // MFA — Status
        ("mfa.status.get", .mfa(.status(.get))),
        ("mfa.status.challenge", .mfa(.status(.challenge))),
        // MFA — Verify
        ("mfa.verify", .mfa(.verify(.init(sessionToken: Fixed.sessionToken, method: .totp, code: Fixed.code)))),
        // OAuth
        ("oauth.providers", .oauth(.providers)),
        ("oauth.authorize", .oauth(.authorize(provider: Fixed.provider))),
        ("oauth.callback", .oauth(.callback(.init(provider: Fixed.provider, code: Fixed.code, state: Fixed.state)))),
        ("oauth.connections", .oauth(.connections)),
        ("oauth.disconnect", .oauth(.disconnect(provider: Fixed.provider)))
    ] }

    @Test("Identity.API.Router corpus")
    func apiRouterCorpus() throws {
        let corpus = try Parity.corpus(of: try Self.routes(), via: Identity.API.Router())
        try assertParity(corpus, fixture: "identity-api-router")
    }

    @Test("Identity.API.Router baseURL-composed corpus")
    func apiRouterBaseURLCorpus() throws {
        // Production shape: the Provider/Consumer configurations wrap the router
        // with a fixed base URL before printing absolute request shapes.
        let router = Identity.API.Router().baseURL(Fixed.baseURL)
        let corpus = try Parity.corpus(of: try Self.routes(), via: router)
        try assertParity(corpus, fixture: "identity-api-router-baseurl")
    }

    @Test("Identity.API.Router round-trips")
    func apiRouterRoundTrips() throws {
        var failures: [String] = []
        let router = Identity.API.Router()
        for (name, route) in try Self.routes() {
            do {
                if try !Parity.roundTrips(route, via: router) {
                    failures.append("\(name): parse(print(route)) != route")
                }
            } catch {
                failures.append("\(name): \(error)")
            }
        }
        try recordNonRoundTrips(failures, fixture: "identity-api-router")
    }
}
