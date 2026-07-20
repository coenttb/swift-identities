//
//  Identity.View.Delete.Confirm.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/09/2024.
//

import Foundation
import HTML
import IdentitiesTypes
import Server_Vapor
import Translating
import Webpage

extension Identity.Deletion {
    package enum Confirm {}
}

extension Identity.Deletion.Confirm {
    package struct View: HTML.View {
        let redirectURL: URL

        package init(
            redirectURL: URL
        ) {
            self.redirectURL = redirectURL
        }

        private static var confirmationId: String { "delete-confirmation-id" }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    div {
                        TranslatedString(
                            dutch: "✓ Account verwijderd",
                            english: "✓ Account deleted"
                        )
                    }
                    .css
                    .fontWeight(.bold)
                    .color(.text.success)
                    .textAlign(.center)
                    .margin(bottom: .rem(1))

                    Paragraph {
                        TranslatedString(
                            dutch:
                                "Uw account en alle bijbehorende gegevens zijn permanent verwijderd.",
                            english:
                                "Your account and all associated data have been permanently deleted."
                        )
                    }
                    .css
                    .font(.body)
                    .textAlign(.center)
                    .margin(bottom: .rem(1))
                    .color(.text.primary)

                    Paragraph {
                        TranslatedString(
                            dutch: "Bedankt voor het gebruik van onze diensten.",
                            english: "Thank you for using our services."
                        )
                    }
                    .css
                    .font(.body(.small))
                    .textAlign(.center)
                    .color(.text.secondary)
                    .margin(bottom: .rem(2))

                    Paragraph {
                        TranslatedString(
                            dutch: "U wordt over 5 seconden doorgestuurd naar de hoofdpagina.",
                            english: "You will be redirected to the main page in 5 seconds."
                        )
                    }
                    .css
                    .font(.body(.small))
                    .textAlign(.center)
                    .color(.text.secondary)
                    .margin(bottom: .rem(2))
                    .color(.text.primary)

                    Link(href: .init(redirectURL.relativePath)) {
                        TranslatedString(
                            dutch: "Klik hier als u niet automatisch wordt doorgestuurd",
                            english: "Click here if you are not automatically redirected"
                        ).description
                    }
                    .linkColor(.text.primary)
                    .fontWeight(.medium)
                    .font(.body(.small))
                    .textAlign(.center)
                }
                .css
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .mobile { $0.maxWidth(.identityComponentMobile) }
                .margin(horizontal: .auto)
                .textAlign(.center)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Account Verwijderd",
                        english: "Account Deleted"
                    )
                }
                .css
                .color(.text.primary)
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.confirmationId)
            .css
            .width(.percent(100))

            script {
                #"""
                    document.addEventListener('DOMContentLoaded', function() {
                        // Clear any stored authentication data
                        if (typeof localStorage !== 'undefined') {
                            localStorage.clear();
                        }
                        if (typeof sessionStorage !== 'undefined') {
                            sessionStorage.clear();
                        }

                        // Redirect after 5 seconds
                        setTimeout(function() {
                            window.location.href = '\#(redirectURL.absoluteString)';
                        }, 5000);
                    });
                """#
            }
        }
    }
}
