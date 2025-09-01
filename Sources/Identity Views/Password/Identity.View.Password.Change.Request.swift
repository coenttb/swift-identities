//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 17/10/2024.
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

extension Identity.Password.Change.Request {
    package struct View: HTML {
        let formActionURL: URL
        let redirectOnSuccess: URL

        package  init(
            formActionURL: URL,
            redirectOnSuccess: URL
        ) {
            self.formActionURL = formActionURL
            self.redirectOnSuccess = redirectOnSuccess
        }

        private static var pagemodule_change_password_id: String { "pagemodule_change_password_id" }

        package  var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                div {
                VStack {
                    CoenttbHTML.Paragraph {
                        TranslatedString(
                            dutch: "Voer uw huidige wachtwoord en uw nieuwe wachtwoord in.",
                            english: "Enter your current password and your new password."
                        )
                    }
                    .font(.body(.small))
                    .textAlign(.center)
                    .color(.text.secondary)
                    
                    form(
                        action: .init(self.formActionURL.relativePath),
                        method: .post
                    ) {
                        VStack {
                            Input(
                                codingKey: Identity.Password.Change.Request.CodingKeys.currentPassword,
                                type: .password(
                                    .init(
                                        placeholder: .init(TranslatedString(dutch: "Huidig wachtwoord", english: "Current password").description)
                                    )
                                )
                            )
                            
                            Input(
                                codingKey: Identity.Password.Change.Request.CodingKeys.newPassword,
                                type: .password(
                                    .init(
                                        placeholder: .init(TranslatedString(dutch: "Nieuw wachtwoord", english: "New password").description)
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
                            .flexContainer(
                                justification: .center,
                                itemAlignment: .center,
                                media: .desktop
                            )
                            .width(.percent(100))
                        }
                    }
                    .id("form-change-password")
                }
            }
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Wachtwoord wijzigen",
                        english: "Change Password"
                    )
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.pagemodule_change_password_id)
            .width(.percent(100))

            script {"""
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
                            const pageModule = document.getElementById("\(Self.pagemodule_change_password_id)");
                            pageModule.outerHTML = \(html: Identity.Password.Change.Request.View.Confirmation(redirectOnSuccess: self.redirectOnSuccess));
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
            """}
        }
    }
}

extension Identity.Password.Change.Request.View {
    package struct Confirmation: HTML {
        package let redirectOnSuccess: URL

        package init(
            redirectOnSuccess: URL
        ) {
            self.redirectOnSuccess = redirectOnSuccess
        }

        package  var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    CoenttbHTML.Paragraph {
                        TranslatedString(
                            dutch: "Uw wachtwoord is succesvol gewijzigd.",
                            english: "Your password has been successfully changed."
                        )
                    }
                    .textAlign(.center)
                    .margin(bottom: .rem(1))

                    CoenttbHTML.Paragraph {
                        TranslatedString(
                            dutch: "U kunt nu inloggen met uw nieuwe wachtwoord.",
                            english: "You can now log in with your new password."
                        )
                    }
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
                .textAlign(.center)
                .alignItems(.center)
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Wachtwoord gewijzigd",
                        english: "Password Changed"
                    )
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .width(.percent(100))
        }
    }
}
