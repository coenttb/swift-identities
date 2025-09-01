//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/09/2024.
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

//extension Identity.Creation.View {
//    package enum Main: HTML {
//        case request(Identity.Creation.Request.View)
//        case requestConfirmReceipt(Identity.Creation.Request.View.ConfirmReceipt)
//        case verify(Identity.Creation.Verification.View)
//
//        package var body: some HTML {
//            switch self {
//            case .request(let request):
//                request
//            case .requestConfirmReceipt(let requestReceivedConfirmation):
//                requestReceivedConfirmation
//            case .verify(let verify):
//                verify
//            }
//        }
//    }
//}

extension Identity.Creation.Request {
    package struct View: HTML {
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

        package var body: some HTML {
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
                            .color(.text.primary.reverse())
                            .width(.percent(100))
                            .justifyContent(.center)

                            div {
                                HTMLText("\(String.already_have_an_account.capitalizingFirstLetter().questionmark) ")
                                Link(href: .init(loginHref.relativePath)) {
                                    String.login.capitalizingFirstLetter()
                                }
                                .linkColor(.branding.primary)
                            }
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
                .id("form-create-identity")
                .width(.percent(100))
                .maxWidth(.rem(30), media: .desktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    String.create_your_account.capitalizingFirstLetter()
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.pagemodule_create_identity)
            .width(.percent(100))

            script {"""
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
            """}
        }
    }
}

extension Identity.Creation.Request.View {
    package struct ConfirmReceipt: HTML {

        let loginHref: URL

        package init(
            loginHref: URL
        ) {
            self.loginHref = loginHref
        }

        package var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    CoenttbHTML.Paragraph {
                        [
                            String.your_account_creation_request_has_been_received,
                            String.please_check_your_email_to_complete_the_process
                        ]
                            .map(\.period)
                            .map { $0.capitalizingFirstLetter() }
                            .joined(separator: " ")

                    }
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
                .width(.percent(100))
                .maxWidth(.rem(30), media: .desktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    "Account Request Confirmation"
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .width(.percent(100))
        }
    }
}

extension Identity.Creation.Verification {
    package struct View: HTML {
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

        package var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack(alignment: .center) {
                    div {}
                        .id("spinner")
                    h2 { "message" }
                        .id("message")
                }
                .textAlign(.center)
                .alignItems(.center)
                .textAlign(.start, media: .mobile)
                .alignItems(.leading, media: .mobile)
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)

            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Verificatie in uitvoering...",
                        english: "Verification in Progress..."
                    )
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.pagemodule_verify_id)
            .width(.percent(100))

            script {"""
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
            """}
        }
    }
}

extension Identity.Creation.Verification.View {
    package struct Confirmation: HTML {
        let redirectURL: URL

        package init(redirectURL: URL) {
            self.redirectURL = redirectURL
        }

        package var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack(alignment: .center) {
                    CoenttbHTML.Paragraph {
                        TranslatedString(
                            dutch: "Uw account is succesvol geverifieerd!",
                            english: "Your account has been successfully verified!"
                        )
                    }
                    .textAlign(.center)
                    .margin(bottom: .rem(1))

                    CoenttbHTML.Paragraph {
                        TranslatedString(
                            dutch: "U wordt over 5 seconden doorgestuurd naar de inlogpagina.",
                            english: "You will be redirected to the login page in 5 seconds."
                        )
                    }
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
                .textAlign(.center)
                .alignItems(.center)
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    "Account Verified"
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .width(.percent(100))
        }
    }
}
