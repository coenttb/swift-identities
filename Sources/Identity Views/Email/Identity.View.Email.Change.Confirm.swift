//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 17/10/2024.
//

import Foundation
import HTML
import IdentitiesTypes
import ServerFoundationVapor
import Translating
import Webpage

extension Identity.Email.Change.Confirmation {
    package struct View: HTML.View {
        let redirect: URL

        package init(
            redirect: URL
        ) {
            self.redirect = redirect
        }

        private static var confirmationId: String { "email-change-confirmation-id" }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    Paragraph {
                        TranslatedString(
                            dutch: "Je e-mailadres is succesvol gewijzigd.",
                            english: "Your email address has been successfully changed."
                        )
                    }
                    .css
                    .font(.body)
                    .textAlign(.center)
                    .color(.text.primary.reverse())
                    .margin(bottom: .medium)

                    Paragraph {
                        TranslatedString(
                            dutch: "Je wordt nu doorgestuurd naar je account pagina.",
                            english: "You will now be redirected to your account page."
                        )
                    }
                    .css
                    .font(.body(.small))
                    .textAlign(.center)
                    .color(.text.secondary)
                    .margin(bottom: .large)

                    Link(href: .init(redirect.relativePath)) {
                        TranslatedString(
                            dutch: "Klik hier als je niet automatisch wordt doorgestuurd",
                            english: "Click here if you are not automatically redirected"
                        ).description
                    }
                    .linkColor(.branding.primary)
                    .fontWeight(.medium)
                    .font(.body(.small))
                    .textAlign(.center)
                }
                .css
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .mobile { $0.maxWidth(.identityComponentMobile) }
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "E-mailadres Wijziging Voltooid",
                        english: "Email Change Complete"
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
                """
                    document.addEventListener('DOMContentLoaded', function() {
                        setTimeout(function() {
                            window.location.href = '\(redirect.relativePath)';
                        }, 5000); // Redirect after 5 seconds
                    });
                """
            }
        }
    }
}
