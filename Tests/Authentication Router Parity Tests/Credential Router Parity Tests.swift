//
//  Credential Router Parity Tests.swift
//  swift-authentication
//
//  Batch-0 corpus for the swift-url-routing credential routers this package
//  consumes (`RFC_7617.Basic`/`RFC_6750.Bearer` carry live API traffic),
//  plus the `Authorization`-header print-time transforms that
//  Identity Shared declares (`setBearerAuth`, `setReauthorizationToken`).
//

import Foundation
import IdentitiesTypes
import Identity_Shared
import Testing
import URL_Routing_Test_Support

@Suite("Credential Router Parity")
struct CredentialRouterParityTests {

    @Test("RFC_6750.Bearer.Router Authorization header emission")
    func bearerAuthCorpus() throws {
        let router = RFC_6750.Bearer.Router()
        let corpus = try Parity.corpus(
            of: [("bearer.fixed-token", try RFC_6750.Bearer(token: Fixed.token))],
            via: router
        )
        try assertParity(corpus, fixture: "bearer-auth-router")
        #expect(try Parity.roundTrips(try RFC_6750.Bearer(token: Fixed.token), via: router))
    }

    @Test("RFC_7617.Basic.Router Authorization header emission")
    func basicAuthCorpus() throws {
        let router = RFC_7617.Basic.Router()
        let credentials = try RFC_7617.Basic(userID: Fixed.email, password: Fixed.password)
        let corpus = try Parity.corpus(
            of: [("basic.fixed-credentials", credentials)],
            via: router
        )
        try assertParity(corpus, fixture: "basic-auth-router")
        #expect(try Parity.roundTrips(credentials, via: router))
    }

    @Test("Identity Shared setBearerAuth header transform")
    func setBearerAuthCorpus() throws {
        // Production shape: an erased Identity router wrapped with the
        // Identity Shared print-time Authorization transform.
        let router = Identity.API.Router().setBearerAuth(Fixed.token)
        let corpus = try Parity.corpus(
            of: [
                ("logout.current+bearer", Identity.API.logout(.current)),
                ("delete.confirm+bearer", Identity.API.delete(.confirm)),
            ],
            via: router
        )
        try assertParity(corpus, fixture: "identity-shared-set-bearer-auth")
    }

    @Test("Identity Shared setReauthorizationToken header transform")
    func setReauthorizationTokenCorpus() throws {
        let router = Identity.API.Router().setReauthorizationToken(Fixed.reauthToken)
        let corpus = try Parity.corpus(
            of: [("reauthorize+token", Identity.API.reauthorize(.init(password: Fixed.password)))],
            via: router
        )
        try assertParity(corpus, fixture: "identity-shared-set-reauthorization-token")
    }
}
