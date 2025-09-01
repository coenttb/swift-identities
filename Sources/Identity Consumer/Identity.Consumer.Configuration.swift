//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 14/02/2025.
//

import Identity_Shared
import Identity_Views
import Identity_Frontend
import Dependencies
import Foundation
import IdentitiesTypes
import URLRouting
import Vapor
import ServerFoundation
import CoenttbHTML
import Coenttb_Web

extension Identity.Consumer {
    public struct Configuration: Sendable {
        public var provider: Identity.Consumer.Configuration.Provider
        public var consumer: Identity.Consumer.Configuration.Consumer

        public init(provider: Identity.Consumer.Configuration.Provider, consumer: Identity.Consumer.Configuration.Consumer) {
            self.provider = provider
            self.consumer = consumer
        }
    }
}

extension Identity.Consumer.Configuration: TestDependencyKey {
    public static let testValue: Self = .init(
        provider: .testValue,
        consumer: .testValue
    )
}

extension DependencyValues {
    public var identity: Identity.Consumer.Configuration {
        get { self[Identity.Consumer.Configuration.self] }
        set { self[Identity.Consumer.Configuration.self] = newValue }
    }
}

extension Identity.Consumer.Configuration.Consumer: TestDependencyKey {
    public static let testValue: Self = .live(
        baseURL: .init(string: "/")!,
        cookies: .init(accessToken: .testValue, refreshToken: .testValue, reauthorizationToken: .testValue),
        router: Identity.Consumer.Route.Router().eraseToAnyParserPrinter(),
        client: .testValue,
        currentUserName: { nil },
        branding: .init(
            logo: .init(logo: .warning, href: .init(string: "/")!),
            favicons: .init(icon: .init(lightMode: .init(string: "/")!, darkMode: .init(string: "/")!), apple_touch_icon: "", manifest: "", maskIcon: ""),
            footer_links: []
        ),
        navigation: .default,
        redirect: .live()
    )
}

extension Identity.Consumer.Configuration {
    public struct Consumer: Sendable {
        public var baseURL: URL

        public var domain: String?
        public var cookies: Identity.Frontend.Configuration.Cookies
        public var router: AnyParserPrinter<URLRequestData, Identity.Consumer.Route> {
            didSet {
                self.router = router.baseURL(self.baseURL.absoluteString).eraseToAnyParserPrinter()
            }
        }

        public var client: Identity.Consumer.Client

        public var currentUserName: @Sendable () -> String?
        public var canonicalHref: @Sendable (Identity.Consumer.View) -> URL?
        public var hreflang: @Sendable (Identity.Consumer.View, Translating.Language) -> URL

        public var branding: Branding
        public var navigation: Navigation
        public var redirect: Identity.Consumer.Configuration.Redirect
        public var rateLimiters: RateLimiters

        public init(
            baseURL: URL,
            domain: String?,
            cookies: Identity.Frontend.Configuration.Cookies,
            router: AnyParserPrinter<URLRequestData, Identity.Consumer.Route>,
            client: Identity.Consumer.Client,
            currentUserName: @Sendable @escaping () -> String?,
            canonicalHref: @Sendable @escaping (Identity.Consumer.View) -> URL?,
            hreflang: @Sendable @escaping (Identity.Consumer.View, Translating.Language) -> URL,
            branding: Branding,
            navigation: Navigation,
            redirect: Identity.Consumer.Configuration.Redirect,
            rateLimiters: RateLimiters
        ) {
            self.baseURL = baseURL
            self.domain = domain
            self.cookies = cookies
            self.router = router
            self.client = client
            self.currentUserName = currentUserName
            self.canonicalHref = canonicalHref
            self.hreflang = hreflang
            self.branding = branding
            self.navigation = navigation
            self.redirect = redirect
            self.rateLimiters = rateLimiters
        }
    }
}

extension Identity.Consumer.Configuration.Consumer {
    public static func live(
        baseURL: URL,
        domain: String? = nil,
        cookies: Identity.Frontend.Configuration.Cookies,
        router: AnyParserPrinter<URLRequestData, Identity.Consumer.Route>,
        client: Identity.Consumer.Client,
        currentUserName: @escaping @Sendable () -> String?,
        canonicalHref: @escaping @Sendable (Identity.Consumer.View) -> URL? = {
            @Dependency(\.identity.consumer.router) var router
            return router.url(for: .view($0))
        },
        hreflang: @escaping @Sendable (Identity.Consumer.View, Translating.Language) -> URL = { view, _ in
            @Dependency(\.identity.consumer.router) var router
            return router.url(for: .view(view))
        },
        branding: Identity.Consumer.Configuration.Branding,
        navigation: Identity.Consumer.Configuration.Navigation,
        redirect: Identity.Consumer.Configuration.Redirect,
        rateLimiters: RateLimiters = .init()
    ) -> Self {
        .init(
            baseURL: baseURL,
            domain: domain,
            cookies: cookies,
            router: router,
            client: client,
            currentUserName: currentUserName,
            canonicalHref: canonicalHref,
            hreflang: hreflang,
            branding: branding,
            navigation: navigation,
            redirect: redirect,
            rateLimiters: rateLimiters
        )
    }
}

extension Identity.Consumer.Configuration {
    public struct Redirect: Sendable {
        public var createProtected: @Sendable () -> URL
        public var loginProtected: @Sendable () -> URL
        public var logoutSuccess: @Sendable () -> URL
        public var loginSuccess: @Sendable () -> URL
        public var passwordResetSuccess: @Sendable () -> URL
        public var emailChangeConfirmSuccess: @Sendable () -> URL
        public var createVerificationSuccess: @Sendable () -> URL

        public init(
            createProtected: @escaping @Sendable () -> URL,
            createVerificationSuccess: @escaping @Sendable () -> URL,
            loginProtected: @escaping @Sendable () -> URL,
            logoutSuccess: @escaping @Sendable () -> URL,
            loginSuccess: @escaping @Sendable () -> URL,
            passwordResetSuccess: @escaping @Sendable () -> URL,
            emailChangeConfirmSuccess: @escaping @Sendable () -> URL
        ) {
            self.createProtected = createProtected
            self.loginProtected = loginProtected
            self.logoutSuccess = logoutSuccess
            self.loginSuccess = loginSuccess
            self.passwordResetSuccess = passwordResetSuccess
            self.emailChangeConfirmSuccess = emailChangeConfirmSuccess
            self.createVerificationSuccess = createVerificationSuccess
        }
    }
}

extension Identity.Consumer.Configuration.Redirect {
    public static func live(
        createProtected: @escaping @Sendable () -> URL = {
            @Dependency(\.identity.consumer.router) var router
            return URL(string: "/")!
        },
        createVerificationSuccess: @escaping @Sendable () -> URL = {
            @Dependency(\.identity.consumer.router) var router
            return router.url(for: .view(.login))
        },
        loginProtected: @escaping @Sendable () -> URL = {
            return URL(string: "/")!
        },
        logoutSuccess: @escaping @Sendable () -> URL = {
            @Dependency(\.identity.consumer.router) var router
            return router.url(for: .view(.login))
        },
        loginSuccess: @escaping @Sendable () -> URL = {
            @Dependency(\.identity.consumer.router) var router
            return URL(string: "/")!
        },
        passwordResetSuccess: @escaping @Sendable () -> URL = {
            @Dependency(\.identity.consumer.router) var router
            return router.url(for: .view(.login))
        },
        emailChangeConfirmSuccess: @escaping @Sendable () -> URL = {
            @Dependency(\.identity.consumer.router) var router
            return router.url(for: .view(.login))
        }
    ) -> Self {
        .init(
            createProtected: createProtected,
            createVerificationSuccess: createVerificationSuccess,
            loginProtected: loginProtected,
            logoutSuccess: logoutSuccess,
            loginSuccess: loginSuccess,
            passwordResetSuccess: passwordResetSuccess,
            emailChangeConfirmSuccess: emailChangeConfirmSuccess
        )

    }
}

extension Identity.Consumer.Configuration.Redirect {
    public static func toHome() -> Self {
        @Dependency(\.identity.consumer.navigation.home) var home

        return .init(
            createProtected: { home },
            createVerificationSuccess: { home },
            loginProtected: { home },
            logoutSuccess: { home },
            loginSuccess: { home },
            passwordResetSuccess: { home },
            emailChangeConfirmSuccess: { home }
        )
    }
}

extension Identity.Consumer.Configuration {
    public typealias Navigation = Identity.Frontend.Configuration.Navigation
}

extension Identity.Consumer.Configuration {
    public typealias Branding = Identity.Frontend.Configuration.Branding
}

extension Identity.Consumer.Configuration {
    public struct Provider: Sendable {
        public var baseURL: URL
        public var domain: String?
        public var router: AnyParserPrinter<URLRequestData, Identity.API>

        public init(
            baseURL: URL,
            domain: String?,
            router: AnyParserPrinter<URLRequestData, Identity.API>
        ) {
            self.baseURL = baseURL
            self.domain = domain
            self.router = router.baseURL(baseURL.absoluteString).eraseToAnyParserPrinter()
        }
    }
}

extension Identity.Consumer.Configuration.Provider: TestDependencyKey {
    public static let testValue: Self = .init(
        baseURL: .init(string: "/")!,
        domain: nil,
        router: Identity.API.Router().eraseToAnyParserPrinter()
    )
}



extension Identity.Consumer.Configuration.Branding {
    public static func _title(for view: Identity.Consumer.View) -> TranslatedString {
        switch view {
        case .authenticate(let authenticate):
            switch authenticate {
            case .credentials:
                return .init(
                    dutch: "Inloggen",
                    english: "Sign In"
                )
            }
        case .create(let create):
            switch create {
            case .request:
                return .init(
                    dutch: "Account Aanmaken",
                    english: "Create Account"
                )
            case .verify:
                return .init(
                    dutch: "Account Verifiëren",
                    english: "Verify Account"
                )
            }
        case .delete:
            return .init(
                dutch: "Account Verwijderen",
                english: "Delete Account"
            )
        case .logout:
            return .init(
                dutch: "Uitloggen",
                english: "Sign Out"
            )
        case .email(let email):
            switch email {
            case .change(let change):
                switch change {
                case .request:
                    return .init(
                        dutch: "E-mailadres Wijzigen",
                        english: "Change Email Address"
                    )
                case .reauthorization:
                    return .init(
                        dutch: "Bevestig Identiteit",
                        english: "Confirm Identity"
                    )
                case .confirm:
                    return .init(
                        dutch: "E-mail Bevestigen",
                        english: "Confirm Email"
                    )
                }
            }
        case .password(let password):
            switch password {
            case .reset(let reset):
                switch reset {
                case .request:
                    return .init(
                        dutch: "Wachtwoord Herstellen",
                        english: "Reset Password"
                    )
                case .confirm:
                    return .init(
                        dutch: "Nieuw Wachtwoord Instellen",
                        english: "Set New Password"
                    )
                }
            case .change(let change):
                switch change {
                case .request:
                    return .init(
                        dutch: "Wachtwoord Wijzigen",
                        english: "Change Password"
                    )
                }
            }
        }
    }
}

extension Identity.Consumer.Configuration.Branding {
    public static func _description(for view: Identity.Consumer.View) -> TranslatedString {
        switch view {
        case .authenticate(let authenticate):
            switch authenticate {
            case .credentials:
                return .init(
                    dutch: "Voer je e-mailadres en wachtwoord in om toegang te krijgen tot je account.",
                    english: "Enter your email address and password to access your account."
                )
            }
        case .create(let create):
            switch create {
            case .request:
                return .init(
                    dutch: "Maak een nieuw account aan om van alle functies gebruik te maken.",
                    english: "Create a new account to access all features."
                )
            case .verify:
                return .init(
                    dutch: "Voer de verificatiecode in die we naar je e-mailadres hebben gestuurd.",
                    english: "Enter the verification code we've sent to your email address."
                )
            }
        case .delete:
            return .init(
                dutch: "Je staat op het punt je account en alle bijbehorende gegevens permanent te verwijderen.",
                english: "You're about to permanently delete your account and all associated data."
            )
        case .logout:
            return .init(
                dutch: "Je wordt uitgelogd van je huidige sessie.",
                english: "You'll be signed out of your current session."
            )
        case .email(let email):
            switch email {
            case .change(let change):
                switch change {
                case .request:
                    return .init(
                        dutch: "Voer het nieuwe e-mailadres in dat je aan je account wilt koppelen.",
                        english: "Enter the new email address you want to associate with your account."
                    )
                case .reauthorization:
                    return .init(
                        dutch: "Voor je veiligheid, bevestig je identiteit om wijzigingen aan te brengen.",
                        english: "For your security, please confirm your identity to make changes."
                    )
                case .confirm:
                    return .init(
                        dutch: "Voer de verificatiecode in die we naar je nieuwe e-mailadres hebben gestuurd.",
                        english: "Enter the verification code we've sent to your new email address."
                    )
                }
            }
        case .password(let password):
            switch password {
            case .reset(let reset):
                switch reset {
                case .request:
                    return .init(
                        dutch: "Voer je e-mailadres in om een link te ontvangen waarmee je je wachtwoord kunt herstellen.",
                        english: "Enter your email address to receive a link to reset your password."
                    )
                case .confirm:
                    return .init(
                        dutch: "Stel een nieuw wachtwoord in voor je account.",
                        english: "Set a new password for your account."
                    )
                }
            case .change(let change):
                switch change {
                case .request:
                    return .init(
                        dutch: "Wijzig je huidige wachtwoord om de beveiliging van je account te verbeteren.",
                        english: "Change your current password to improve your account security."
                    )
                }
            }
        }
    }
}
