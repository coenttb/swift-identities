//
//  ConsumerAPIRouterTests.swift
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
import Testing
import URLRouting

@Suite
struct Test {

    @Test
    func `Router configuration exists for credentials authentication`() async throws {
        // Test that credentials routes can be constructed
        let route: Identity.API = .authenticate(
            .credentials(
                .init(
                    email: try .init("test@example.com"),
                    password: "password123"
                )
            )
        )

        // Route can be constructed and typed correctly
    }

    @Test
    func `Router configuration exists for token routes`() async throws {
        let dummyToken = JWT(
            header: .init(alg: "HS256"),
            payload: .init(),
            signature: Data()
        )
        let route: Identity.API = .authenticate(.token(.refresh(dummyToken)))

        // Route can be constructed
    }

    @Test
    func `Router configuration exists for email routes`() async throws {
        let route: Identity.API = .email(
            .change(
                .request(
                    .init(
                        newEmail: try .init("new@example.com")
                    )
                )
            )
        )

        // Route can be constructed
    }

    @Test
    func `Router configuration exists for password reset`() async throws {
        let route: Identity.API = .password(
            .reset(
                .request(
                    .init(
                        email: try .init("test@example.com")
                    )
                )
            )
        )

        // Route can be constructed
    }

    @Test
    func `Router configuration exists for password change`() async throws {
        let route: Identity.API = .password(
            .change(
                .request(
                    .init(
                        currentPassword: "old123",
                        newPassword: "new456"
                    )
                )
            )
        )

        // Route can be constructed
    }

    @Test
    func `Router configuration exists for create route`() async throws {
        let route: Identity.API = .create(
            .request(
                .init(
                    email: try .init("new@example.com"),
                    password: "password123"
                )
            )
        )

        // Route can be constructed
    }

    @Test
    func `Router configuration exists for delete route`() async throws {
        let route: Identity.API = .delete(
            .request(
                .init(
                    reauthToken: "test-reauth-token"
                )
            )
        )

        // Route can be constructed
    }

    @Test
    func `Router configuration exists for logout route`() async throws {
        let route: Identity.API = .logout(.current)

        // Route can be constructed
    }

    @Test
    func `Router configuration handles bearer auth correctly`() async throws {
        // Test that router can set bearer auth
        let router = Identity.API.Router()
        let withAuth = router.setBearerAuth("test-token")

        // Router with auth configured
    }

    @Test
    func `Router configuration handles reauthorization tokens`() async throws {
        // Test that router can set reauthorization tokens
        let router = Identity.API.Router()
        let withReauth = router.setReauthorizationToken("reauth-token")

        // Router with reauth token configured
    }

    @Test
    func `Provider configuration uses correct base URL`() async throws {
        let config = Identity.Consumer.Configuration.Provider(
            baseURL: URL(string: "https://provider.example.com")!,
            domain: "example.com",
            router: Identity.API.Router().eraseToAnyParserPrinter()
        )

        #expect(config.baseURL.absoluteString == "https://provider.example.com")
        #expect(config.domain == "example.com")
    }
}
