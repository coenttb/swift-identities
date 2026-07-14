//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/10/2024.
//

import Foundation
import HTML
import IdentitiesTypes
import ServerFoundationVapor
import Translating
import Webpage

extension Identity.Email.Change.Request {
    package struct View: HTML.View {
        let formActionURL: URL
        let homeHref: URL
        let reauthorizationURL: URL

        package init(
            formActionURL: URL,
            homeHref: URL,
            reauthorizationURL: URL
        ) {
            self.formActionURL = formActionURL
            self.homeHref = homeHref
            self.reauthorizationURL = reauthorizationURL
        }

        private static var pagemodule_request_email_change_id: String {
            "pagemodule_request_email_change_id"
        }
        private static var form_id: String { "form-request-email-change" }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    div {
                        Paragraph {
                            TranslatedString(
                                dutch:
                                    "Voer uw nieuwe e-mailadres in. We sturen een email naar beide e-mailadressen.",
                                english:
                                    "Enter your new email address. We'll send an email to both email addresses."
                            )
                        }
                        .css
                        .font(.body(.small))
                        .textAlign(.center)
                        .color(.text.secondary)

                        form(
                            action: .init(self.formActionURL.relativePath),
                            method: .post
                        ) {
                            VStack {
                                Input(
                                    codingKey: Identity.Email.Change.Request.CodingKeys.newEmail,
                                    type: .email(
                                        .init(
                                            placeholder: .init(value: "New Email")
                                        )
                                    )
                                )
                                .focusOnPageLoad()

                                VStack {
                                    Button(
                                        button: .init(type: .submit)
                                    ) {
                                        TranslatedString(
                                            dutch: "Verzoek indienen",
                                            english: "Submit Request"
                                        )
                                    }
                                    .css
                                    .color(.text.primary.reverse())
                                    .width(.percent(100))
                                    .justifyContent(.center)

                                    Link(
                                        TranslatedString(
                                            dutch: "Terug naar home",
                                            english: "Back to Home"
                                        ).description,
                                        href: .init(homeHref.relativePath)
                                    )
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
                        .id(Self.form_id)
                    }
                    .css
                    .width(.percent(100))
                    .maxWidth(.identityComponentDesktop)
                    .mobile { $0.maxWidth(.identityComponentMobile) }
                    .margin(horizontal: .auto)
                }

            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "E-mailadres wijzigen",
                        english: "Change Email Address"
                    )
                }
                .css
                .color(.text.primary)
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.pagemodule_request_email_change_id)
            .css
            .width(.percent(100))

            script {
                #"""
                document.addEventListener('DOMContentLoaded', function() {
                    const form = document.getElementById('\#(Self.form_id)');
                    const errorContainer = document.createElement('div');
                    errorContainer.id = 'error-container';
                    errorContainer.style.color = 'red';
                    errorContainer.style.marginTop = '10px';
                    errorContainer.style.display = 'none';
                    form.appendChild(errorContainer);

                    form.addEventListener('submit', async function(event) {
                        event.preventDefault();
                        errorContainer.style.display = 'none';
                        errorContainer.textContent = '';

                        const formData = new FormData(form);
                        const newEmail = formData.get('\#(Identity.Email.Change.Request.CodingKeys.newEmail.rawValue)');

                        // Email validation regex - inline for now to avoid escaping issues
                        const emailRegex = /^[A-Za-z0-9][A-Za-z0-9._%+-]*@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/i;

                        if (!emailRegex.test(newEmail)) {
                            displayError('\#(TranslatedString(
                            dutch: "Voer een geldig e-mailadres in.",
                            english: "Please enter a valid email address."
                        ))');
                            return;
                        }

                        try {
                            const response = await fetch(form.action, {
                                method: form.method,
                                headers: {
                                    'Content-Type': 'application/x-www-form-urlencoded',
                                    'Accept': 'application/json'
                                },
                                body: new URLSearchParams(formData).toString(),
                                credentials: 'same-origin'
                            });

                            // Check if reauthorization is required
                            if (response.status === 401 && response.headers.get('X-Requires-Reauth') === 'true') {
                                // Redirect to reauthorization page
                                window.location.href = '\#(self.reauthorizationURL.absoluteString)';
                                return;
                            }

                            const data = await response.json();

                            if (data.success) {
                                const pageModule = document.getElementById("\#(Self.pagemodule_request_email_change_id)");
                                pageModule.outerHTML = \#(html: Identity.Email.Change.Request.View.ReceiptConfirmation(homeHref: self.homeHref));
                            } else {
                                throw new Error(data.reason || '\#(TranslatedString(
                                dutch: "Verzoek om e-mailadres te wijzigen mislukt",
                                english: "Email change request failed"
                            ))');
                            }
                        } catch (error) {
                            console.error("Error occurred:", error);
                            displayError(error.message);
                        }
                    });

                    function displayError(message) {
                        errorContainer.textContent = message;
                        errorContainer.style.display = 'block';
                    }
                });
                """#
            }
        }
    }
}

//
//                        if (!response.ok) {
//                            throw new Error(data.reason || '\#(TranslatedString(
//                                dutch: "Verzoek om e-mailadres te wijzigen mislukt",
//                                english: "Email change request failed"
//                            ))');
//                        }

extension Identity.Email.Change.Request.View {
    package struct ReceiptConfirmation: HTML.View {
        let homeHref: URL

        package init(
            homeHref: URL
        ) {
            self.homeHref = homeHref
        }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    Paragraph {
                        TranslatedString(
                            dutch:
                                "We hebben een bevestigingsmail gestuurd naar beide e-mailadressen.",
                            english: "We've sent a confirmation email to both email addresses."
                        )
                    }
                    .css
                    .textAlign(.center)
                    .margin(bottom: .rem(1))

                    Paragraph {
                        TranslatedString(
                            dutch:
                                "Volg de instructies in de e-mails om de wijziging te voltooien.",
                            english: "Follow the instructions in the emails to complete the change."
                        )
                    }
                    .css
                    .textAlign(.center)
                    .margin(bottom: .rem(2))

                    Link(
                        TranslatedString(
                            dutch: "Terug naar home",
                            english: "Back to Home"
                        ).description,
                        href: .init(homeHref.relativePath)
                    )
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
                        dutch: "Verzoek ontvangen",
                        english: "Request Received"
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
