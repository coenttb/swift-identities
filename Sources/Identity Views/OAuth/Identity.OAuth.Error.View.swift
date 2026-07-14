//
//  Identity.OAuth.Error.View.swift
//  coenttb-identities
//
//  OAuth error display view
//

import Foundation
import HTML
import IdentitiesTypes
import Language
import Translating
import Webpage

extension Identity.OAuth.Error {
    public struct View: HTML.View {
        let errorMessage: String
        let retryHref: URL
        let cancelHref: URL

        public init(
            errorMessage: String,
            retryHref: URL,
            cancelHref: URL
        ) {
            self.errorMessage = errorMessage
            self.retryHref = retryHref
            self.cancelHref = cancelHref
        }

        public var body: some HTML.View {
            PageModule(theme: .content) {
                VStack(alignment: .center) {
                    // Error icon
                    div {
                        "⚠️"
                    }
                    .css
                    .fontSize(.rem(3))
                    .marginBottom(.medium)

                    // Title
                    h2 {
                        TranslatedString(
                            dutch: "OAuth Fout",
                            english: "OAuth Error"
                        )
                    }
                    //                    .font(.title(.regular))
                    .css
                    .fontSize(.large)
                    .color(.red600)
                    .marginBottom(.medium)

                    // Error message
                    div {
                        p {
                            TranslatedString(
                                dutch: "Er is een fout opgetreden tijdens het inloggen:",
                                english: "An error occurred during authentication:"
                            )
                        }
                        .css
                        .marginBottom(.small)

                        div {
                            code { errorMessage }
                                .css
                                .padding(.medium)
                                .backgroundColor(.background.secondary)
                                .borderRadius(.rem(0.375))
                                .display(.block)
                                .wordBreak(.breakAll)
                                .fontFamily(.monospace)
                                .fontSize(.rem(0.9))
                        }
                    }
                    .css
                    .marginBottom(.large)

                    // Actions
                    HStack(alignment: .middle) {
                        a(href: .init(retryHref.absoluteString)) {
                            TranslatedString(
                                dutch: "Opnieuw proberen",
                                english: "Try Again"
                            )
                        }
                        .class("btn btn-primary")
                        .css
                        .padding(vertical: .medium, horizontal: .large)
                        .backgroundColor(.blue500)
                        .color(.white)
                        .borderRadius(.rem(0.5))
                        .textDecoration(TextDecoration.none)
                        .display(.inlineBlock)
                        .hover { $0.backgroundColor(.blue600) }

                        a(href: .init(cancelHref.absoluteString)) {
                            TranslatedString(
                                dutch: "Annuleren",
                                english: "Cancel"
                            )
                        }
                        .class("btn btn-secondary")
                        .css
                        .padding(vertical: .medium, horizontal: .large)
                        .backgroundColor(.gray200)
                        .color(.gray700)
                        .borderRadius(.rem(0.5))
                        .textDecoration(TextDecoration.none)
                        .display(.inlineBlock)
                        .hover { $0.backgroundColor(.gray300) }
                    }
                    .css
                    .gap(.length(.rem(1.5)))
                    .justifyContent(.center)

                    // Help text
                    div {
                        p {
                            TranslatedString(
                                dutch:
                                    "Als dit probleem aanhoudt, neem dan contact op met de beheerder.",
                                english:
                                    "If this problem persists, please contact the administrator."
                            )
                        }
                        .css
                        .fontSize(.rem(0.9))
                        .color(.gray600)
                        .textAlign(.center)
                    }
                    .css
                    .marginTop(.extraLarge)
                }
                .css
                .width(.percent(100))
                .maxWidth(.px(500))
                .margin(.auto)
                .padding(.extraLarge)
            }
            .css
            .maxWidth(.px(800))
            .margin(.auto)
        }
    }
}

// Namespace
extension Identity.OAuth {
    public enum Error {}
}
