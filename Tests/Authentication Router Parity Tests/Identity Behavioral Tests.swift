import Foundation
import IdentitiesTypes
import Identity_Consumer
import Identity_Frontend
import Server
import Server_Vapor
import Testing
import URLRouting

@Suite("Identity behavioral contracts")
struct IdentityBehavioralTests {

    @Test
    func `Consumer live construction preserves the public access spelling`() {
        let baseURL = URL(string: "https://example.com")!
        let router = Identity.Route.Router().eraseToAnyParserPrinter()

        let configuration = Identity.Consumer.Configuration.Consumer.live.init(
            baseURL: baseURL,
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

        #expect(configuration.baseURL == baseURL)
        #expect(configuration.currentUserName() == "currentuser")
    }

    @Test
    func `Set-Cookie rendering succeeds for a valid token`() throws {
        let response = try Server.Response().setting(
            cookie: Identity.Cookies.Names.accessToken,
            token: "signed-token",
            configuration: .init(path: "/", isHTTPOnly: true)
        )

        let cookieHeader = response.headers["Set-Cookie"]?.first
        #expect(cookieHeader.map(String.init(describing:))?.contains("signed-token") == true)
    }

    @Test
    func `Set-Cookie encoding failures propagate`() {
        var didThrow = false

        do {
            _ = try Server.Response().setting(
                cookie: Identity.Cookies.Names.accessToken,
                token: "invalid\u{0001}token",
                configuration: .init(path: "/", isHTTPOnly: true)
            )
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }
}
