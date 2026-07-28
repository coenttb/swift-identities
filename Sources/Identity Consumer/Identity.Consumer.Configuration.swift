//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 14/02/2025.
//

import Dependencies
import Foundation
import HTML
import HTTP_Cookies
import IdentitiesTypes
import Identity_Frontend
import Identity_Shared
import Identity_Views
import Server
import Server_Vapor
import Throttling
import URI
import URLRouting
import Vapor

extension Identity.Consumer {
    public struct Configuration: Sendable {
        public var provider: Identity.Consumer.Configuration.Provider
        public var consumer: Identity.Consumer.Configuration.Consumer

        public init(
            provider: Identity.Consumer.Configuration.Provider,
            consumer: Identity.Consumer.Configuration.Consumer
        ) {
            self.provider = provider
            self.consumer = consumer
        }
    }
}

extension Identity.Consumer.Configuration: Dependency.Key.Test {
    public static let testValue: Self = .init(
        provider: .testValue,
        consumer: .testValue
    )
}

extension Identity.Consumer.Configuration.Consumer: Dependency.Key.Test {
    public static let testValue: Self = .live(
        baseURL: URL(string: "/")!,
        cookies: Identity.Frontend.Configuration.Cookies(
            accessToken: .init(maxAge: 60 * 60 * 24),
            refreshToken: .init(maxAge: 60 * 60 * 24),
            reauthorizationToken: .init(maxAge: 60 * 60 * 24)
        ),
        router: Identity.Route.Router().eraseToAnyParserPrinter(),
        currentUserName: { String?.none },
        branding: Identity.Frontend.Configuration.Branding(
            logo: Identity.View.Logo(logo: "🔐", href: URL(string: "/")!),
            footer_links: []
        ),
        navigation: Identity.Frontend.Configuration.Navigation.default,
        redirect: Identity.Consumer.Configuration.Redirect.live()
    )
}

extension Identity.Consumer.Configuration {
    public struct Consumer: Sendable {
        public var baseURL: URL

        public var domain: String?
        public var cookies: Identity.Frontend.Configuration.Cookies
        public var router: AnyParserPrinter<URLRequestData, Identity.Route> {
            didSet {
                self.router = BaseURLRouter(baseURLString: self.baseURL.absoluteString, upstream: router).eraseToAnyParserPrinter()
            }
        }

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
            router: AnyParserPrinter<URLRequestData, Identity.Route>,
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
        router: AnyParserPrinter<URLRequestData, Identity.Route>,
        currentUserName: @escaping @Sendable () -> String?,
        canonicalHref: @escaping @Sendable (Identity.Consumer.View) -> URL? = { _ in
            // Return nil - canonical URLs should be set by the application
            return nil
        },
        hreflang: @escaping @Sendable (Identity.Consumer.View, Translating.Language) -> URL = {
            _,
            _ in
            @Dependency(\.identityConsumerConfiguration) var config
            return config.consumer.baseURL
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
            return URL(string: "/")!
        },
        createVerificationSuccess: @escaping @Sendable () -> URL = {
            @Dependency(\.identityConsumerConfiguration) var config
            return config.consumer.router.url(for: .authenticate(.view(.credentials)))
        },
        loginProtected: @escaping @Sendable () -> URL = {
            return URL(string: "/")!
        },
        logoutSuccess: @escaping @Sendable () -> URL = {
            @Dependency(\.identityConsumerConfiguration) var config
            return config.consumer.router.url(for: .authenticate(.view(.credentials)))
        },
        loginSuccess: @escaping @Sendable () -> URL = {
            return URL(string: "/")!
        },
        passwordResetSuccess: @escaping @Sendable () -> URL = {
            @Dependency(\.identityConsumerConfiguration) var config
            return config.consumer.router.url(for: .authenticate(.view(.credentials)))
        },
        emailChangeConfirmSuccess: @escaping @Sendable () -> URL = {
            @Dependency(\.identityConsumerConfiguration) var config
            return config.consumer.router.url(for: .authenticate(.view(.credentials)))
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
        return .init(
            createProtected: {
                @Dependency(\.identityConsumerConfiguration) var config
                return config.consumer.navigation.home
            },
            createVerificationSuccess: {
                @Dependency(\.identityConsumerConfiguration) var config
                return config.consumer.navigation.home
            },
            loginProtected: {
                @Dependency(\.identityConsumerConfiguration) var config
                return config.consumer.navigation.home
            },
            logoutSuccess: {
                @Dependency(\.identityConsumerConfiguration) var config
                return config.consumer.navigation.home
            },
            loginSuccess: {
                @Dependency(\.identityConsumerConfiguration) var config
                return config.consumer.navigation.home
            },
            passwordResetSuccess: {
                @Dependency(\.identityConsumerConfiguration) var config
                return config.consumer.navigation.home
            },
            emailChangeConfirmSuccess: {
                @Dependency(\.identityConsumerConfiguration) var config
                return config.consumer.navigation.home
            }
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
            self.router = BaseURLRouter(baseURLString: baseURL.absoluteString, upstream: router).eraseToAnyParserPrinter()
        }
    }
}

extension Identity.Consumer.Configuration.Provider: Dependency.Key.Test {
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
        case .mfa(let mfa):
            switch mfa {
            case .verify:
                return .init(
                    dutch: "Twee-factor Authenticatie",
                    english: "Two-Factor Authentication"
                )
            case .manage:
                return .init(
                    dutch: "Authenticatie Beheren",
                    english: "Manage Authentication"
                )
            case .totp(let totp):
                switch totp {
                case .setup:
                    return .init(
                        dutch: "Authenticatie App Instellen",
                        english: "Set Up Authenticator App"
                    )
                case .confirmSetup:
                    return .init(
                        dutch: "Authenticatie App Bevestigen",
                        english: "Confirm Authenticator App"
                    )
                case .manage:
                    return .init(
                        dutch: "Authenticatie App Beheren",
                        english: "Manage Authenticator App"
                    )
                }
            case .backupCodes(let codes):
                switch codes {
                case .display:
                    return .init(
                        dutch: "Back-up Codes",
                        english: "Backup Codes"
                    )
                case .verify:
                    return .init(
                        dutch: "Back-up Code Verificatie",
                        english: "Backup Code Verification"
                    )
                }
            }
        case .oauth:
            return .init(
                dutch: "OAuth Authenticatie",
                english: "OAuth Authentication"
            )
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
                    dutch:
                        "Voer je e-mailadres en wachtwoord in om toegang te krijgen tot je account.",
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
                dutch:
                    "Je staat op het punt je account en alle bijbehorende gegevens permanent te verwijderen.",
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
                        dutch:
                            "Voer het nieuwe e-mailadres in dat je aan je account wilt koppelen.",
                        english:
                            "Enter the new email address you want to associate with your account."
                    )
                case .reauthorization:
                    return .init(
                        dutch:
                            "Voor je veiligheid, bevestig je identiteit om wijzigingen aan te brengen.",
                        english: "For your security, please confirm your identity to make changes."
                    )
                case .confirm:
                    return .init(
                        dutch:
                            "Voer de verificatiecode in die we naar je nieuwe e-mailadres hebben gestuurd.",
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
                        dutch:
                            "Voer je e-mailadres in om een link te ontvangen waarmee je je wachtwoord kunt herstellen.",
                        english:
                            "Enter your email address to receive a link to reset your password."
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
                        dutch:
                            "Wijzig je huidige wachtwoord om de beveiliging van je account te verbeteren.",
                        english: "Change your current password to improve your account security."
                    )
                }
            }
        case .mfa(let mfa):
            switch mfa {
            case .verify:
                return .init(
                    dutch: "Voer je verificatiecode in om door te gaan.",
                    english: "Enter your verification code to continue."
                )
            case .manage:
                return .init(
                    dutch: "Beheer je twee-factor authenticatiemethoden.",
                    english: "Manage your two-factor authentication methods."
                )
            case .totp(let totp):
                switch totp {
                case .setup:
                    return .init(
                        dutch: "Scan de QR-code met je authenticatie app.",
                        english: "Scan the QR code with your authenticator app."
                    )
                case .confirmSetup:
                    return .init(
                        dutch:
                            "Voer de code uit je authenticatie app in om de instelling te voltooien.",
                        english: "Enter the code from your authenticator app to complete setup."
                    )
                case .manage:
                    return .init(
                        dutch: "Beheer je authenticatie app instellingen.",
                        english: "Manage your authenticator app settings."
                    )
                }
            case .backupCodes(let codes):
                switch codes {
                case .display:
                    return .init(
                        dutch: "Bewaar deze back-up codes op een veilige plek.",
                        english: "Keep these backup codes in a safe place."
                    )
                case .verify:
                    return .init(
                        dutch: "Voer een van je back-up codes in.",
                        english: "Enter one of your backup codes."
                    )
                }
            }
        case .oauth:
            return .init(
                dutch: "Log in met een externe dienst.",
                english: "Sign in with an external service."
            )
        }
    }
}

// MARK: - Dependency Values
//
// Keypath access rather than `@Dependency(Identity.Consumer.Configuration.self)`: the property wrapper
// requires a `liveValue` this app-supplied configuration does not have. See the note in
// Identity.Frontend.Configuration.swift.
extension Dependency.Values {
    public var identityConsumerConfiguration: Identity.Consumer.Configuration {
        get { self[Identity.Consumer.Configuration.self] }
        set { self[Identity.Consumer.Configuration.self] = newValue }
    }
}

// A stateless, declarative `Sendable` router that bakes a base URL into an already-erased
// upstream router. `router.baseURL(_:)` yields an `RFC_3986.URI.BaseURLPrinter`, which is NOT
// `Sendable`, so it cannot be erased directly (`eraseToAnyParserPrinter()` requires
// `Self: Sendable`). Wrapping the composition in a `Sendable` declarative router restores an
// honestly-`Sendable` value that can be erased and stored in the `Sendable` configuration.
// Precedent: `Identity Provider`'s `BaseURLRouter` (Identity.Provider.Configuration.swift:137),
// generalised over `Output` because Consumer bakes base URLs into both `Identity.Route` and
// `Identity.API` routers.
private struct BaseURLRouter<Output: Sendable>: ParserPrinter, Sendable {
    let baseURLString: String
    let upstream: AnyParserPrinter<URLRequestData, Output>

    var body: some URLRouting.Router<Output> {
        upstream.baseURL(baseURLString)
    }
}
