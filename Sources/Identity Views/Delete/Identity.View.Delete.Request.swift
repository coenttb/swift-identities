//
//  Identity.View.Delete.Request.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/09/2024.
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

extension Identity.Deletion.Request {
    package struct View: HTML {
        let deleteRequestAction: URL
        let cancelAction: URL
        let homeHref: URL
        let reauthorizationURL: URL
        
        package init(
            deleteRequestAction: URL,
            cancelAction: URL,
            homeHref: URL,
            reauthorizationURL: URL
        ) {
            self.deleteRequestAction = deleteRequestAction
            self.cancelAction = cancelAction
            self.homeHref = homeHref
            self.reauthorizationURL = reauthorizationURL
        }
        
        private static var pagemodule_delete_request_id: String { "pagemodule-delete-request" }
        private static var form_id: String { "form-delete-request" }
        
        package var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    div {
                        div {
                            div {
                                TranslatedString(
                                    dutch: "⚠️ Waarschuwing",
                                    english: "⚠️ Warning"
                                )
                            }
                            .fontWeight(.bold)
                            .color(.text.error)
                            .margin(bottom: .rem(0.5))
                            
                            CoenttbHTML.Paragraph {
                                TranslatedString(
                                    dutch: "Dit zal permanent uw account en alle bijbehorende gegevens verwijderen. Deze actie kan niet ongedaan worden gemaakt.",
                                    english: "This will permanently delete your account and all associated data. This action cannot be undone."
                                )
                            }
                            .font(.body(.small))
                            .color(.text.secondary)
                        }
                        .padding(.rem(1))
                        .backgroundColor(.background.error.map{ $0.opacity(0.3) })
                        .borderRadius(.medium)
                        .margin(bottom: .rem(1.5))
                        
                        CoenttbHTML.Paragraph {
                            TranslatedString(
                                dutch: "Voer uw wachtwoord in om door te gaan met het verwijderen van uw account.",
                                english: "Enter your password to proceed with deleting your account."
                            )
                        }
                        .font(.body(.regular))
                        .textAlign(.center)
                        .color(.text.secondary)
                        .margin(bottom: .rem(1))
                        
                        form(
                            action: .init(self.deleteRequestAction.relativePath),
                            method: .post
                        ) {
                            VStack {
                                Input(
                                    codingKey: Identity.Authentication.Credentials.CodingKeys.password,
                                    type: .password(
                                        .init(
                                            placeholder: .init(String.password.capitalizingFirstLetter().description)
                                        )
                                    )
                                )
                                .focusOnPageLoad()
                                
                                VStack {
                                    Button(
                                        button: .init(type: .submit)
                                    ) {
                                        TranslatedString(
                                            dutch: "Account Verwijderen",
                                            english: "Delete Account"
                                        )
                                    }
                                    .backgroundColor(.background.error)
                                    .color(.text.primary.reverse())
                                    .width(.percent(100))
                                    .justifyContent(.center)
                                    
                                    Link(href: .init(homeHref.relativePath)) {
                                        TranslatedString(
                                            dutch: "Annuleren",
                                            english: "Cancel"
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
                        .id(Self.form_id)
                    }
                    .width(.percent(100))
                    .maxWidth(.identityComponentDesktop)
                    .maxWidth(.identityComponentMobile, media: .mobile)
                    .margin(horizontal: .auto)
                }
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Account Verwijderen",
                        english: "Delete Account"
                    )
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.pagemodule_delete_request_id)
            .width(.percent(100))
            
            script {#"""
            document.addEventListener('DOMContentLoaded', function() {
                const form = document.getElementById('\#(Self.form_id)');
                const errorContainer = document.createElement('div');
                errorContainer.id = 'error-container';
                errorContainer.style.color = 'red';
                errorContainer.style.marginTop = '10px';
                errorContainer.style.textAlign = 'center';
                errorContainer.style.display = 'none';
                form.appendChild(errorContainer);
                
                form.addEventListener('submit', async function(event) {
                    event.preventDefault();
                    errorContainer.style.display = 'none';
                    errorContainer.textContent = '';
                    
                    const formData = new FormData(form);
                    const password = formData.get('\#(Identity.Authentication.Credentials.CodingKeys.password.rawValue)');
                    
                    try {
                        // First, get reauthorization token
                        const reauthResponse = await fetch('\#(reauthorizationURL.absoluteString)', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/x-www-form-urlencoded',
                                'Accept': 'application/json'
                            },
                            body: new URLSearchParams({
                                \#(Identity.Authentication.Credentials.CodingKeys.password.rawValue): password
                            }).toString(),
                            credentials: 'same-origin'
                        });
                        
                        if (!reauthResponse.ok) {
                            const reauthData = await reauthResponse.json();
                            throw new Error(reauthData.reason || '\#(TranslatedString(
                                dutch: "Ongeldig wachtwoord",
                                english: "Invalid password"
                            ))');
                        }
                        
                        const reauthData = await reauthResponse.json();
                        
                        // Get the reauthorization token from the response
                        const reauthToken = reauthData.data?.token || '';
                        
                        if (!reauthToken) {
                            throw new Error('\#(TranslatedString(
                                dutch: "Herautorisatie mislukt",
                                english: "Reauthorization failed"
                            ))');
                        }
                        
                        // Then submit deletion request with reauth token
                        const deleteResponse = await fetch(form.action, {
                            method: form.method,
                            headers: {
                                'Content-Type': 'application/x-www-form-urlencoded',
                                'Accept': 'application/json'
                            },
                            body: new URLSearchParams({
                                \#(Identity.Deletion.Request.CodingKeys.reauthToken.rawValue): reauthToken
                            }).toString(),
                            credentials: 'same-origin'
                        });
                        
                        if (!deleteResponse.ok) {
                            const deleteData = await deleteResponse.json();
                            throw new Error(deleteData.reason || '\#(TranslatedString(
                                dutch: "Verwijderingsverzoek mislukt",
                                english: "Deletion request failed"
                            ))');
                        }
                        
                        const deleteData = await deleteResponse.json();
                        
                        if (deleteData.success) {
                            // Replace view with pending status
                            const pageModule = document.getElementById('\#(Self.pagemodule_delete_request_id)');
                            pageModule.outerHTML = \#(html: Identity.Deletion.Request.View.PendingReceipt(
                                daysRemaining: 7,
                                cancelAction: self.cancelAction,
                                homeHref: self.homeHref
                            ));
                        } else {
                            throw new Error(deleteData.message || '\#(TranslatedString(
                                dutch: "Verwijderingsverzoek mislukt",
                                english: "Deletion request failed"
                            ))');
                        }
                    } catch (error) {
                        console.error('Error:', error);
                        displayError(error.message);
                    }
                });
                
                function displayError(message) {
                    errorContainer.textContent = message;
                    errorContainer.style.display = 'block';
                }
            });
            """#}
        }
    }
}

extension Identity.Deletion.Request.View {
    package struct PendingReceipt: HTML {
        let daysRemaining: Int
        let cancelAction: URL
        let homeHref: URL
        
        package init(
            daysRemaining: Int,
            cancelAction: URL,
            homeHref: URL
        ) {
            self.daysRemaining = daysRemaining
            self.cancelAction = cancelAction
            self.homeHref = homeHref
        }
        
        package var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    div {
                        TranslatedString(
                            dutch: "✓ Verwijderingsverzoek ontvangen",
                            english: "✓ Deletion request received"
                        )
                    }
                    .fontWeight(.medium)
                    .color(.text.success)
                    .textAlign(.center)
                    .margin(bottom: .rem(1))
                    
                    CoenttbHTML.Paragraph {
                        TranslatedString(
                            dutch: "Uw account is gepland voor verwijdering. U heeft een bedenktijd van \(daysRemaining) dagen.",
                            english: "Your account is scheduled for deletion. You have a grace period of \(daysRemaining) days."
                        )
                    }
                    .textAlign(.center)
                    .margin(bottom: .rem(1.5))
                    
                    div {
                        Header(4) {
                            TranslatedString(
                                dutch: "\(daysRemaining) dagen resterend",
                                english: "\(daysRemaining) days remaining"
                            )
                        }
                        .margin(bottom: .rem(0.5))
                        
                        CoenttbHTML.Paragraph {
                            TranslatedString(
                                dutch: "U kunt de verwijdering op elk moment tijdens deze periode annuleren.",
                                english: "You can cancel the deletion at any time during this period."
                            )
                        }
                        .font(.body(.small))
                    }
                    .padding(.rem(1))
                    .backgroundColor(.background.warning/*.opacity(0.1)*/)
                    .borderRadius(.medium)
                    .textAlign(.center)
                    .margin(bottom: .rem(2))
                    
                    VStack {
                        form(
                            action: .init(cancelAction.relativePath),
                            method: .post
                        ) {
                            Button(
                                button: .init(type: .submit)
                            ) {
                                TranslatedString(
                                    dutch: "Verwijdering Annuleren",
                                    english: "Cancel Deletion"
                                )
                            }
                            .backgroundColor(.background.success)
                            .color(.text.primary.reverse())
                            .width(.percent(100))
                            .justifyContent(.center)
                        }
                        
                        Link(href: .init(homeHref.relativePath)) {
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
                    .maxWidth(.identityComponentDesktop)
                    .maxWidth(.identityComponentMobile, media: .mobile)
                    .margin(horizontal: .auto)
                }
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Account Verwijdering In Behandeling",
                        english: "Account Deletion Pending"
                    )
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .width(.percent(100))
        }
    }
}
