//
//  ConsumerMiddlewareTests.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 31/10/2025.
//

import Dependencies
import Dependencies_Test_Support
import Foundation
import IdentitiesTypes
import Identity_Consumer
import Identity_Shared
import JWT
import Testing
@preconcurrency import Vapor

@Suite
struct Test {

    @Test
    func `Middleware initializes with default authenticators`() async throws {
        let middleware = Identity.Consumer.Middleware()
        // Middleware created successfully
    }

    @Test
    func `Token authenticator initializes correctly`() async throws {
        let authenticator = Identity.Consumer.TokenAuthenticator()
        // Authenticator created successfully
    }

    @Test
    func `Credentials authenticator initializes correctly`() async throws {
        let authenticator = Identity.Consumer.CredentialsAuthenticator()
        // Authenticator created successfully
    }

    @Test
    func `Middleware configuration is valid`() async throws {
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
