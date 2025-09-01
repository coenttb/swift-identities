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

extension Identity.Reauthorization {
    package struct View<CodingKey: RawRepresentable>: HTML where CodingKey.RawValue == String {
        let codingKey: CodingKey
        let currentUserName: String
        let passwordResetHref: URL
        let confirmFormAction: URL
        let redirectOnSuccess: URL

        package init(
            codingKey: CodingKey = Identity.Email.Change.Reauthorization.CodingKeys.password,
            currentUserName: String,
            passwordResetHref: URL,
            confirmFormAction: URL,
            redirectOnSuccess: URL
        ) {
            self.codingKey = codingKey
            self.currentUserName = currentUserName
            self.passwordResetHref = passwordResetHref
            self.confirmFormAction = confirmFormAction
            self.redirectOnSuccess = redirectOnSuccess
        }

        package var body: some HTML {

                PageModule(theme: .confirmAccess) {
                    VStack {
                        HTMLGroup {
                            HTMLMarkdown { """
                              \(
                                  TranslatedString(
                                      dutch: "Ingelogd als",
                                      english: "Signed in as"
                                  )
                              )
                            **\(currentUserName)**.
                            """ }

                            form(
                                action: .init(confirmFormAction.relativePath),
                                method: .post
                            ) {
                                VStack {

                                    Input(
                                        codingKey: self.codingKey,
                                        type: .password(
                                            .init(placeholder: .init(String.password.capitalizingFirstLetter().description))
                                        )
                                    )

                                    Link(href: .init(passwordResetHref.relativePath)) {
                                        String.forgot_password.capitalizingFirstLetter().questionmark
                                    }
                                    .linkColor(.branding.primary)
                                    .font(.body(.small))
                                    .display(.inlineBlock)

                                    VStack {
                                        Button(
                                            button: .init(type: .submit)
                                        ) {
                                            String.continue.capitalizingFirstLetter()
                                        }
                                        .dependency(\.theme.text.primary, .text.primary.reverse())
                                        .width(.percent(100))
                                        .justifyContent(.center)

    //                                    div {
    //                                        HTMLMarkdown {"""
    //                                        **Tip:** You are entering sudo mode. After you've performed a sudo-protected action, you'll only be asked to re-authenticate again after a few hours of inactivity.
    //                                        """}
    //                                        .linkColor(.branding.primary)
    //                                    }
    //                                    .fontSize(.secondary)
    //                                    .textAlign(.center)
                                    }
                                    .flexContainer(
                                        justification: .center,
                                        itemAlignment: .center,
                                        media: .desktop
                                    )
                                }
                            }
                            .id("form-confirm-access")
                            .width(.percent(100))
                            .maxWidth(.identityComponentDesktop)
                            .maxWidth(.identityComponentMobile, media: .mobile)
                            .margin(horizontal: .auto)
                        }
                        .width(.percent(100))
                        .maxWidth(.identityComponentDesktop)
                        .maxWidth(.identityComponentMobile, media: .mobile)
                        .margin(vertical: nil, horizontal: .auto)

                    }
                    .width(.percent(100))

                } title: {
                    Header(3) {
                        String.confirm_access.capitalizingFirstLetter()
                    }
                }

                script {"""
                   document.addEventListener('DOMContentLoaded', function() {
                       const form = document.getElementById("form-confirm-access");
                       const formContainer = form;

                       form.addEventListener('submit', async function(event) {
                           event.preventDefault();
                           const formData = new FormData(form);
                           const password = formData.get('\(Identity.Authentication.Credentials.CodingKeys.password.rawValue)');

                           try {

                               const response = await fetch(form.action, {
                                   method: form.method,
                                   headers: {
                                       'Content-Type': 'application/x-www-form-urlencoded',
                                       'Accept': 'application/json'
                                   },
                                   body: new URLSearchParams({
                                        \(Identity.Authentication.Credentials.CodingKeys.password.rawValue): password
                                   }).toString(),
                                   credentials: 'same-origin'
                               });

                               if (!response.ok) {
                                   throw new Error('Network response was not ok');
                               }

                               const data = await response.json();

                               if (data.success) {
                                   window.location.href = "\(redirectOnSuccess.relativePath)";
                               } else {
                                   throw new Error(data.message || 'Confirmation failed');
                               }

                           } catch (error) {
                               console.error('Error:', error);
                               const messageDiv = document.createElement('div');
                               messageDiv.textContent = 'Login failed. Please try again.';
                               messageDiv.style.color = 'red';
                               messageDiv.style.textAlign = 'center';
                               messageDiv.style.marginTop = '10px';
                               formContainer.appendChild(messageDiv);
                           }
                       });
                   });
                """}

        }
    }
}

extension PageModule.Theme {
    static var confirmAccess: Self {
        authenticationFlow
    }
}

#if canImport(SwiftUI)
import SwiftUI

@MainActor let confirmAccess: some HTML = Identity.Reauthorization.View(
    codingKey: Identity.Creation.Request.CodingKeys.password,
    currentUserName: "Coen ten Thije Boonkkamp",
    passwordResetHref: .desktopDirectory,
    confirmFormAction: .desktopDirectory,
    redirectOnSuccess: .desktopDirectory
)

#Preview {
    HTMLDocument.modern {
        confirmAccess
    }
}

#endif
