//
//  File.swift
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

extension Identity.Creation.Request {
    package struct View: HTML.View {
        let loginHref: URL
        let accountCreateHref: URL
        let createFormAction: URL

        package init(
            loginHref: URL,
            accountCreateHref: URL,
            createFormAction: URL
        ) {
            self.loginHref = loginHref
            self.accountCreateHref = accountCreateHref
            self.createFormAction = createFormAction
        }

        private static let pagemodule_create_identity: String = "pagemodule-create-identity"

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                form(
                    action: .init(createFormAction.relativePath),
                    method: .post
                ) {
                    VStack {
                        Input(
                            codingKey: Identity.Creation.Request.CodingKeys.email,
                            type: .email(
                                .init(placeholder: .init(String.email.description))
                            )
                        )
                        .focusOnPageLoad()

                        Input(
                            codingKey: Identity.Creation.Request.CodingKeys.password,
                            type: .password(
                                .init(
                                    placeholder: .init(String.password.description)
                                )
                            )
                        )

                        VStack {
                            Button(
                                button: .init(type: .submit)
                            ) {
                                String.continue.capitalizingFirstLetter()
                            }
                            .css
                            .color(.text.primary.reverse())
                            .width(.percent(100))
                            .justifyContent(.center)

                            div {
                                span {
                                    "\(String.already_have_an_account.capitalizingFirstLetter().questionmark) "
                                }
                                .css
                                .color(.text.primary)

                                Link(href: .init(loginHref.relativePath)) {
                                    String.login.capitalizingFirstLetter()
                                }
                                .linkColor(.branding.primary)
                            }
                            .css
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
                .id("form-create-identity")
                .css
                .width(.percent(100))
            } title: {
                Header(3) {
                    String.create_your_account.capitalizingFirstLetter()
                }
                .css
                .display(.inlineBlock)
                .textAlign(.center)
                .color(.text.primary)
            }
            .id(Self.pagemodule_create_identity)
            .css
            .width(.percent(100))
            .maxWidth(.identityComponentDesktop)
            .mobile { $0.maxWidth(.identityComponentMobile) }
            .margin(horizontal: .auto)

            script {
                """
                document.addEventListener('DOMContentLoaded', function() {
                    const form = document.getElementById("form-create-identity");

                    form.addEventListener('submit', async function(event) {
                        event.preventDefault();

                        const formData = new FormData(form);
                        const email = formData.get('\(Identity.Creation.Request.CodingKeys.email.rawValue)');
                        const password = formData.get('\(Identity.Creation.Request.CodingKeys.password.rawValue)');

                        try {
                            const response = await fetch(form.action, {
                                method: form.method,
                                headers: {
                                    'Content-Type': 'application/x-www-form-urlencoded',
                                    'Accept': 'application/json'
                                },
                                body: new URLSearchParams({
                                     \(Identity.Creation.Request.CodingKeys.email.rawValue): email,
                                     \(Identity.Creation.Request.CodingKeys.password.rawValue): password
                                }).toString()
                            });

                            if (!response.ok) {
                                throw new Error('Network response was not ok');
                            }

                            const data = await response.json();

                            if (data.success) {
                                const pageModule = document.getElementById("\(Self.pagemodule_create_identity)");
                                pageModule.outerHTML = \(html: Identity.Creation.Request.View.ConfirmReceipt(loginHref: loginHref));
                            } else {
                                throw new Error(data.message || 'Account creation failed');
                            }
                        } catch (error) {
                            console.error('Error:', error);
                            const messageDiv = document.createElement('div');
                            messageDiv.textContent = 'Account creation failed. Please try again.';
                            messageDiv.style.color = 'red';
                            messageDiv.style.textAlign = 'center';
                            messageDiv.style.marginTop = '10px';
                            form.appendChild(messageDiv);
                        }
                    });
                });
                """
            }
        }
    }
}

extension Identity.Creation.Request.View {
    package struct ConfirmReceipt: HTML.View {

        let loginHref: URL

        package init(
            loginHref: URL
        ) {
            self.loginHref = loginHref
        }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    Paragraph {
                        // The pre-port source mapped over a heterogeneous array literal, which the
                        // compiler inferred as [Any] (root: `.map(\.period)` on 'Any'). Both elements
                        // are TranslatedString, so the array is pinned to its real element type here
                        // rather than left to inference.
                        [TranslatedString].init([
                            String.your_account_creation_request_has_been_received,
                            String.please_check_your_email_to_complete_the_process,
                        ])
                        .map(\.period)
                        .map { $0.capitalizingFirstLetter() }
                        .joined(separator: " ")

                    }
                    .css
                    .textAlign(.center)
                    .margin(bottom: .rem(2))

                    //                div {
                    //                    HTMLText("\(String.already_have_an_account.capitalizingFirstLetter().questionmark) ")
                    //                    Link(href: loginHref.relativePath) {
                    //                        String.login.capitalizingFirstLetter()
                    //                    }
                    //                    .linkColor(.branding.primary)
                    //                }
                    //                .fontSize(.secondary)
                    //                .textAlign(.center)
                }
            } title: {
                Header(3) {
                    "Account Request Confirmation"
                }
                .css
                .display(.inlineBlock)
                .textAlign(.center)
                .color(.text.primary)
            }
            .css
            .width(.percent(100))
            .maxWidth(.identityComponentDesktop)
            .mobile { $0.maxWidth(.identityComponentMobile) }
            .margin(horizontal: .auto)
        }
    }
}

extension Identity.Creation.Verification {
    package struct View: HTML.View {
        let verificationAction: URL
        let redirectURL: URL

        package init(
            verificationAction: URL,
            redirectURL: URL
        ) {
            self.verificationAction = verificationAction
            self.redirectURL = redirectURL
        }

        private static let pagemodule_verify_id: String = "pagemodule_verify_id"

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack(alignment: .center) {
                    div {}
                        .id("spinner")
                    h2 { "message" }
                        .id("message")
                        .css
                        .color(.text.primary)
                }
                .css
                .textAlign(.center)
                .alignItems(.center)
                .mobile {
                    $0
                        .textAlign(.start)
                        // `.leading` is not an AlignItems value on the institute surface. The CSS
                        // logical-start alignment is `.start`
                        // (swift-w3c-css/Sources/W3C CSS Alignment/SelfPosition.swift:19 + AlignItems
                        // `.position(_:_:)`), which is what "leading" denoted here.
                        .alignItems(.start)
                }

            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Verificatie in uitvoering...",
                        english: "Verification in Progress..."
                    )
                }
                .css
                .color(.text.primary)
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.pagemodule_verify_id)
            .css
            .width(.percent(100))
            .maxWidth(.identityComponentDesktop)
            .mobile { $0.maxWidth(.identityComponentMobile) }
            .margin(horizontal: .auto)

            script {
                """
                    document.addEventListener('DOMContentLoaded', function() {
                        const urlParams = new URLSearchParams(window.location.search);
                        const token = urlParams.get('token');
                        const email = urlParams.get('email');

                        if (token && email) {
                            verifyEmail(token, email);
                        } else {
                            showMessage('Error: No verification token or email found.', false);
                        }
                    });

                    async function verifyEmail(token, email) {
                        try {
                            const response = await fetch('\(verificationAction.absoluteString)', {
                                method: 'POST',
                                headers: {
                                    'Content-Type': 'application/x-www-form-urlencoded',
                                    'Accept': 'application/json'
                                },
                                body: new URLSearchParams({
                                    token: token,
                                    email: email
                                }).toString()
                            });

                            const data = await response.json();

                            if (data.success) {
                                const pageModule = document.getElementById("\(Self.pagemodule_verify_id)");
                                pageModule.outerHTML = \(html: Identity.Creation.Verification.View.Confirmation(redirectURL: redirectURL));
                                setTimeout(() => { window.location.href = '\(redirectURL.absoluteString)'; }, 5000);

                            } else {
                                console.log(data)
                                throw new Error(data.message || 'Account creation failed');
                            }
                        } catch (error) {
                            console.error("Error occurred:", error);
                            showMessage('An error occurred during verification. Please try again later.', false);
                        }
                    }

                    function showMessage(message, isSuccess) {
                        const messageElement = document.getElementById('message');
                        const spinnerElement = document.getElementById('spinner');
                        messageElement.textContent = message;
                        messageElement.className = isSuccess ? 'success' : 'error';
                        spinnerElement.style.display = 'none';
                    }
                """
            }
        }
    }
}

extension Identity.Creation.Verification.View {
    package struct Confirmation: HTML.View {
        let redirectURL: URL

        package init(redirectURL: URL) {
            self.redirectURL = redirectURL
        }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack(alignment: .center) {
                    Paragraph {
                        TranslatedString(
                            dutch: "Uw account is succesvol geverifieerd!",
                            english: "Your account has been successfully verified!"
                        )
                    }
                    .css
                    .textAlign(.center)
                    .margin(bottom: .rem(1))

                    Paragraph {
                        TranslatedString(
                            dutch: "U wordt over 5 seconden doorgestuurd naar de inlogpagina.",
                            english: "You will be redirected to the login page in 5 seconds."
                        )
                    }
                    .css
                    .textAlign(.center)
                    .margin(bottom: .rem(2))

                    Link(href: .init(redirectURL.relativePath)) {
                        TranslatedString(
                            dutch: "Klik hier als u niet automatisch wordt doorgestuurd",
                            english: "Click here if you are not redirected automatically"
                        )
                    }
                    .linkColor(.text.primary)
                }
                .css
                .textAlign(.center)
                .alignItems(.center)
            } title: {
                Header(3) {
                    "Account Verified"
                }
                .css
                .color(.text.primary)
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .css
            .width(.percent(100))
            .maxWidth(.identityComponentDesktop)
            .mobile { $0.maxWidth(.identityComponentMobile) }
            .margin(horizontal: .auto)
        }
    }
}
