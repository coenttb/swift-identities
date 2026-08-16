//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 17/10/2024.
//

import Foundation
import HTML
import IdentitiesTypes
import Server_Vapor
import Translating
import Webpage

extension Identity.Password.Change.Request {
    package struct View: HTML.View {
        let currentUserName: String
        let formActionURL: URL
        let redirectOnSuccess: URL

        package init(
            currentUserName: String,
            formActionURL: URL,
            redirectOnSuccess: URL
        ) {
            self.currentUserName = currentUserName
            self.formActionURL = formActionURL
            self.redirectOnSuccess = redirectOnSuccess
        }

        private static var pageModuleChangePasswordID: String { "pagemodule_change_password_id" }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                div {
                    VStack {
                        // Syntax rot repaired: the interpolation's continuation lines were indented
                        // LESS than the literal's closing delimiter, which is a parse error on any
                        // toolchain ("insufficient indentation of line in multi-line string
                        // literal"). Re-indented to match the identical, well-formed construct in
                        // the sibling Identity.View.Reauthorize.swift. Content is unchanged.
                        Markdown {
                            """
                              \(
                                  TranslatedString(
                                      dutch: "Ingelogd als",
                                      english: "Signed in as"
                                  )
                              )
                            **\(currentUserName)**.
                            """
                        }
                        .css
                        .textAlign(.center)

                        Paragraph {
                            TranslatedString(
                                dutch: "Voer uw huidige wachtwoord en uw nieuwe wachtwoord in.",
                                english: "Enter your current password and your new password."
                            )
                        }
                        .css
                        .font(.body(.small))
                        .textAlign(.center)
                        .color(.text.secondary)

                        form(
                            action: .init(formActionURL.relativePath),
                            method: .post
                        ) {
                            VStack {
                                Input(
                                    codingKey: Identity.Password.Change.Request.CodingKeys
                                        .currentPassword,
                                    type: .password(
                                        .init(
                                            placeholder: .init(
                                                TranslatedString(
                                                    dutch: "Huidig wachtwoord",
                                                    english: "Current password"
                                                )
                                                .description
                                            )
                                        )
                                    )
                                )

                                Input(
                                    codingKey: Identity.Password.Change.Request.CodingKeys
                                        .newPassword,
                                    type: .password(
                                        .init(
                                            placeholder: .init(
                                                TranslatedString(
                                                    dutch: "Nieuw wachtwoord",
                                                    english: "New password"
                                                )
                                                .description
                                            )
                                        )
                                    )
                                )

                                VStack {
                                    Button(
                                        button: .init(type: .submit)
                                    ) {
                                        TranslatedString(
                                            dutch: "Wachtwoord wijzigen",
                                            english: "Change Password"
                                        )
                                    }
                                    .css
                                    .color(.text.primary.reverse())
                                    .width(.percent(100))
                                    .justifyContent(.center)

                                    Link(href: .init(redirectOnSuccess.relativePath)) {
                                        TranslatedString(
                                            dutch: "Terug naar home",
                                            english: "Back to Home"
                                        ).description
                                    }
                                    .linkColor(.branding.primary)
                                    .fontWeight(.medium)
                                    .font(.body(.small))
                                }
                                .css
                                .desktop {
                                    $0.flexContainer(
                                        justification: .center,
                                        itemAlignment: .center
                                    )
                                }
                                .width(.percent(100))
                            }
                        }
                        .id("form-change-password")
                    }
                }
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Wachtwoord wijzigen",
                        english: "Change Password"
                    )
                }
                .css
                .color(.text.primary)
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.pageModuleChangePasswordID)
            .css
            .width(.percent(100))
            .maxWidth(.identityComponentDesktop)
            .mobile { $0.maxWidth(.identityComponentMobile) }
            .margin(horizontal: .auto)

            script {
                """
                document.addEventListener('DOMContentLoaded', function() {
                    const form = document.getElementById('form-change-password');
                    form.addEventListener('submit', async function(event) {
                        event.preventDefault();
                        const formData = new FormData(form);
                        try {
                            const response = await fetch(form.action, {
                                method: form.method,
                                headers: {
                                    'Content-Type': 'application/x-www-form-urlencoded',
                                    'Accept': 'application/json'
                                },
                                body: new URLSearchParams(formData).toString()
                            });
                            const data = await response.json();
                            if (data.success) {
                                const pageModule = document.getElementById("\(Self.pageModuleChangePasswordID)");
                                pageModule.outerHTML = \(html: Identity.Password.Change.Request.View.Confirmation(redirectOnSuccess: redirectOnSuccess));
                            } else {
                                throw new Error(data.message || '\(TranslatedString(
                                dutch: "Wachtwoord wijzigen mislukt",
                                english: "Password change failed"
                            ))');
                            }
                        } catch (error) {
                            console.error("Error occurred:", error);
                            alert('\(TranslatedString(
                            dutch: "Er is een fout opgetreden. Probeer het later opnieuw.",
                            english: "An error occurred. Please try again later."
                        ))');
                        }
                    });
                });
                """
            }
        }
    }
}

extension Identity.Password.Change.Request.View {
    package struct Confirmation: HTML.View {
        package let redirectOnSuccess: URL

        package init(
            redirectOnSuccess: URL
        ) {
            self.redirectOnSuccess = redirectOnSuccess
        }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    Paragraph {
                        TranslatedString(
                            dutch: "Uw wachtwoord is succesvol gewijzigd.",
                            english: "Your password has been successfully changed."
                        )
                    }
                    .css
                    .textAlign(.center)
                    .margin(bottom: .rem(1))

                    Paragraph {
                        TranslatedString(
                            dutch: "U kunt nu inloggen met uw nieuwe wachtwoord.",
                            english: "You can now log in with your new password."
                        )
                    }
                    .css
                    .textAlign(.center)
                    .margin(bottom: .rem(2))

                    Link(href: .init(redirectOnSuccess.relativePath)) {
                        TranslatedString(
                            dutch: "Terug naar home",
                            english: "Back to Home"
                        ).description
                    }
                    .linkColor(.branding.primary)
                }
                .css
                .textAlign(.center)
                .alignItems(.center)
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .mobile { $0.maxWidth(.identityComponentMobile) }
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Wachtwoord gewijzigd",
                        english: "Password Changed"
                    )
                }
                .css
                .color(.text.primary)
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .css
            .width(.percent(100))
        }
    }
}
