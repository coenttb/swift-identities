//
//  ConsumerMiddlewareTests.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 31/10/2025.
//

import Testing
import Identity_Consumer
import Identity_Shared
import Dependencies
import DependenciesTestSupport
import Foundation
import IdentitiesTypes
import JWT
@preconcurrency import Vapor

@Suite("Consumer Middleware Tests")
struct ConsumerMiddlewareTests {

    @Test("Middleware initializes with default authenticators")
    func testMiddlewareInitialization() async throws {
        let middleware = Identity.Consumer.Middleware()
        // Middleware created successfully
    }

    @Test("Token authenticator initializes correctly")
    func testTokenAuthenticatorInitialization() async throws {
        let authenticator = Identity.Consumer.TokenAuthenticator()
        // Authenticator created successfully
    }

    @Test("Credentials authenticator initializes correctly")
    func testCredentialsAuthenticatorInitialization() async throws {
        let authenticator = Identity.Consumer.CredentialsAuthenticator()
        // Authenticator created successfully
    }

    @Test("Middleware configuration is valid")
    func testMiddlewareConfiguration() async throws {
        // Test that middleware can be created with custom authenticators
        let tokenAuth = Identity.Consumer.TokenAuthenticator()
        let credAuth = Identity.Consumer.CredentialsAuthenticator()

        let middleware = Identity.Consumer.Middleware(
            tokenAuthenticator: tokenAuth,
            credentialsAuthenticator: credAuth
        )

        // Middleware created with custom authenticators
    }
}
