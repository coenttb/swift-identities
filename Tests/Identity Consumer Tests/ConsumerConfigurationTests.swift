//
//  ConsumerConfigurationTests.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 31/10/2025.
//

import Dependencies
import Dependencies_Test_Support
import Foundation
import IdentitiesTypes
import Identity_Consumer
import Identity_Frontend
import Identity_Shared
import ServerFoundation
import Testing
import URLRouting

@Suite
struct Test {

    @Test
    func `Configuration initializes with provider and consumer`() async throws {
        let providerConfig = Identity.Consumer.Configuration.Provider(
            baseURL: URL(string: "https://provider.example.com")!,
            domain: "example.com",
            router: Identity.API.Router().eraseToAnyParserPrinter()
        )

        let consumerConfig = Identity.Consumer.Configuration.Consumer.live(
            baseURL: URL(string: "https://consumer.example.com")!,
            domain: "example.com",
            cookies: .consumer(
                domain: "example.com",
                router: Identity.Route.Router()
            ),
            router: Identity.Route.Router().eraseToAnyParserPrinter(),
            currentUserName: { "testuser" },
            branding: .init(
                logo: Identity.View.Logo(logo: "🔐", href: URL(string: "/")!),
                footer_links: []
            ),
            navigation: .default,
            redirect: .live()
        )

        let configuration = Identity.Consumer.Configuration(
            provider: providerConfig,
            consumer: consumerConfig
        )

        #expect(configuration.provider.baseURL.absoluteString == "https://provider.example.com")
        #expect(configuration.provider.domain == "example.com")
        #expect(configuration.consumer.baseURL.absoluteString == "https://consumer.example.com")
        #expect(configuration.consumer.domain == "example.com")
        #expect(configuration.consumer.currentUserName() == "testuser")
    }

    @Test
    func `Test configuration provides sensible defaults`() async throws {
        let config = Identity.Consumer.Configuration.testValue

        #expect(config.provider.baseURL.absoluteString == "/")
        #expect(config.provider.domain == nil)
        #expect(config.consumer.baseURL.absoluteString == "/")
        #expect(config.consumer.currentUserName() == nil)
    }

    @Test
    func `Consumer configuration with live factory method`() async throws {
        let baseURL = URL(string: "https://example.com")!
        let router = Identity.Route.Router().eraseToAnyParserPrinter()

        let config = Identity.Consumer.Configuration.Consumer.live(
            baseURL: baseURL,
            domain: "example.com",
            cookies: .consumer(domain: "example.com", router: router),
            router: router,
            currentUserName: { "currentuser" },
            branding: .init(
                logo: Identity.View.Logo(logo: "🔐", href: baseURL),
                footer_links: []
            ),
            navigation: .default,
            redirect: .live()
        )

        #expect(config.baseURL == baseURL)
        #expect(config.domain == "example.com")
        #expect(config.currentUserName() == "currentuser")
    }

    @Test
    func `Redirect configuration provides default redirects`() throws {
        withDependencies {
            $0[Identity.Consumer.Configuration.self] = .testValue
        } operation: {
            let redirect = Identity.Consumer.Configuration.Redirect.live()

            let createProtectedURL = redirect.createProtected()
            #expect(createProtectedURL.absoluteString == "/")

            let loginProtectedURL = redirect.loginProtected()
            #expect(loginProtectedURL.absoluteString == "/")

            let logoutSuccessURL = redirect.logoutSuccess()
            #expect(
                logoutSuccessURL.path.contains("credentials"),
                "Logout success should redirect to credentials/login page"
            )

            let loginSuccessURL = redirect.loginSuccess()
            #expect(loginSuccessURL.absoluteString == "/")
        }
    }

    @Test
    func `Redirect configuration to home`() throws {
        withDependencies {
            $0[Identity.Consumer.Configuration.self] = .testValue
        } operation: {
            let redirect = Identity.Consumer.Configuration.Redirect.toHome()

            let createProtectedURL = redirect.createProtected()
            #expect(createProtectedURL.absoluteString.contains("/"))

            let loginSuccessURL = redirect.loginSuccess()
            #expect(loginSuccessURL.absoluteString.contains("/"))

            let logoutSuccessURL = redirect.logoutSuccess()
            #expect(logoutSuccessURL.absoluteString.contains("/"))
        }
    }

    @Test
    func `Cookie configuration for consumer`() async throws {
        let router = Identity.Route.Router()
        let cookies = Identity.Frontend.Configuration.Cookies.consumer(
            domain: "example.com",
            router: router,
            crossOrigin: false
        )

        #expect(cookies.accessToken.domain == "example.com")
        #expect(cookies.accessToken.isSecure == true)
        #expect(cookies.accessToken.isHTTPOnly == true)
        #expect(cookies.accessToken.sameSitePolicy == .lax)
        #expect(cookies.refreshToken.domain == "example.com")
        #expect(cookies.refreshToken.isSecure == true)
        #expect(cookies.reauthorizationToken.sameSitePolicy == .strict)
    }

    @Test
    func `Cookie configuration for consumer with cross-origin`() async throws {
        let router = Identity.Route.Router()
        let cookies = Identity.Frontend.Configuration.Cookies.consumer(
            domain: "example.com",
            router: router,
            crossOrigin: true
        )

        #expect(cookies.accessToken.sameSitePolicy == .none)
        #expect(cookies.refreshToken.sameSitePolicy == .none)
        #expect(cookies.reauthorizationToken.sameSitePolicy == .strict)  // Always strict
    }

    @Test
    func `Development cookie configuration`() async throws {
        let router = Identity.Route.Router()
        let cookies = Identity.Frontend.Configuration.Cookies.consumerDevelopment(router: router)

        #expect(cookies.accessToken.domain == nil)
        #expect(cookies.accessToken.isSecure == false)
        #expect(cookies.accessToken.sameSitePolicy == .none)
        #expect(cookies.refreshToken.isSecure == false)
        #expect(cookies.reauthorizationToken.isSecure == false)
        #expect(cookies.reauthorizationToken.sameSitePolicy == .lax)
    }

    @Test
    func `Branding provides localized titles for views`() async throws {
        let credentialsTitle = Identity.Consumer.Configuration.Branding._title(
            for: .authenticate(.credentials)
        )
        #expect(credentialsTitle.english == "Sign In")
        #expect(credentialsTitle.dutch == "Inloggen")

        let createTitle = Identity.Consumer.Configuration.Branding._title(
            for: .create(.request)
        )
        #expect(createTitle.english == "Create Account")
        #expect(createTitle.dutch == "Account Aanmaken")

        let deleteTitle = Identity.Consumer.Configuration.Branding._title(
            for: .delete(.request)
        )
        #expect(deleteTitle.english == "Delete Account")
        #expect(deleteTitle.dutch == "Account Verwijderen")
    }

    @Test
    func `Branding provides localized descriptions for views`() async throws {
        let credentialsDesc = Identity.Consumer.Configuration.Branding._description(
            for: .authenticate(.credentials)
        )
        #expect(credentialsDesc.english.contains("email"))
        #expect(credentialsDesc.dutch.contains("e-mailadres"))

        let createDesc = Identity.Consumer.Configuration.Branding._description(
            for: .create(.request)
        )
        #expect(createDesc.english.contains("account"))
        #expect(createDesc.dutch.contains("account"))
    }
}
