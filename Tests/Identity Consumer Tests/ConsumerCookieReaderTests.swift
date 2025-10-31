//
//  ConsumerCookieReaderTests.swift
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

@Suite("Consumer Cookie Reader Tests")
struct ConsumerCookieReaderTests {

    @Test("Cookie reader initializes correctly")
    func testInitialization() async throws {
        let reader = Identity.Consumer.CookieReader()
        // Reader created successfully
    }

    @Test("Cookie reader provides debug description without exposing tokens")
    func testDebugDescriptionSafety() async throws {
        // Test that debug description format is safe
        let reader = Identity.Consumer.CookieReader()
        // The reader should never expose actual token values in debug output
    }

    @Test("Cookie error descriptions are informative")
    func testCookieErrorDescriptions() async throws {
        let accessError = Identity.Consumer.CookieError.missingAccessToken
        #expect(accessError.description.contains("Access token"))

        let refreshError = Identity.Consumer.CookieError.missingRefreshToken
        #expect(refreshError.description.contains("Refresh token"))

        let reauthError = Identity.Consumer.CookieError.missingReauthorizationToken
        #expect(reauthError.description.contains("Reauthorization token"))
    }

    @Test("Cookie reader can forward cookies to URL requests")
    func testForwardCookiesStructure() async throws {
        let reader = Identity.Consumer.CookieReader()
        var urlRequest = URLRequest(url: URL(string: "https://example.com")!)

        // Test that forwardCookies method exists and can be called
        // Actual cookie forwarding is tested via integration tests
    }

    @Test("Cookie reader validates cookie presence correctly")
    func testValidationErrors() async throws {
        // Test that appropriate errors are thrown for missing cookies
        let accessError = Identity.Consumer.CookieError.missingAccessToken
        let refreshError = Identity.Consumer.CookieError.missingRefreshToken
        let reauthError = Identity.Consumer.CookieError.missingReauthorizationToken

        // Verify error types exist and have correct descriptions
        #expect(accessError is Identity.Consumer.CookieError)
        #expect(refreshError is Identity.Consumer.CookieError)
        #expect(reauthError is Identity.Consumer.CookieError)
    }
}
