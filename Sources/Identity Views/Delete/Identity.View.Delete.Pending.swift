//
//  Identity.View.Delete.Pending.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/09/2024.
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

extension Identity.Deletion {
    package enum Pending {}
}

extension Identity.Deletion.Pending {
    package struct View: HTML {
        let daysRemaining: Int
        let cancelAction: URL
        let confirmAction: URL
        let homeHref: URL
        
        package init(
            daysRemaining: Int,
            cancelAction: URL,
            confirmAction: URL,
            homeHref: URL
        ) {
            self.daysRemaining = daysRemaining
            self.cancelAction = cancelAction
            self.confirmAction = confirmAction
            self.homeHref = homeHref
        }
        
        private static var pagemodule_delete_pending_id: String { "pagemodule-delete-pending" }
        private static var cancel_form_id: String { "form-cancel-deletion" }
        private static var confirm_form_id: String { "form-confirm-deletion" }
        
        package var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    // Status indicator
                    div {
                        if daysRemaining > 0 {
                            TranslatedString(
                                dutch: "⏳ Verwijdering gepland",
                                english: "⏳ Deletion scheduled"
                            )
                        } else {
                            TranslatedString(
                                dutch: "⚠️ Klaar voor verwijdering",
                                english: "⚠️ Ready for deletion"
                            )
                        }
                    }
                    .fontWeight(.medium)
                    .color(daysRemaining > 0 ? .text.warning : .text.error)
                    .textAlign(.center)
                    .margin(bottom: .rem(1))
                    
                    CoenttbHTML.Paragraph {
                        if daysRemaining > 0 {
                            TranslatedString(
                                dutch: "Uw account wordt over \(daysRemaining) dagen verwijderd.",
                                english: "Your account will be deleted in \(daysRemaining) days."
                            )
                        } else {
                            TranslatedString(
                                dutch: "De bedenktijd is verstreken. U kunt nu de verwijdering bevestigen.",
                                english: "The grace period has expired. You can now confirm the deletion."
                            )
                        }
                    }
                    .textAlign(.center)
                    .margin(bottom: .rem(1.5))
                    
                    // Grace period info box
                    div {
                        Header(4) {
                            if daysRemaining > 0 {
                                TranslatedString(
                                    dutch: "\(daysRemaining) dagen resterend",
                                    english: "\(daysRemaining) days remaining"
                                )
                            } else {
                                TranslatedString(
                                    dutch: "Bedenktijd verstreken",
                                    english: "Grace period expired"
                                )
                            }
                        }
                        .margin(bottom: .rem(0.5))
                        
                        CoenttbHTML.Paragraph {
                            if daysRemaining > 0 {
                                TranslatedString(
                                    dutch: "U kunt de verwijdering nog annuleren.",
                                    english: "You can still cancel the deletion."
                                )
                            } else {
                                TranslatedString(
                                    dutch: "Bevestig de verwijdering of annuleer het verzoek.",
                                    english: "Confirm the deletion or cancel the request."
                                )
                            }
                        }
                        .font(.body(.small))
                    }
                    .padding(.rem(1))
                    .backgroundColor(daysRemaining > 0 ? .background.warning.map { $0.opacity(0.3) } : .background.error.map { $0.opacity(0.3) })
                    .borderRadius(.medium)
                    .textAlign(.center)
                    .margin(bottom: .rem(2))
                    
                    // Action buttons
                    VStack {
                        // Cancel button (always shown)
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
                        .id(Self.cancel_form_id)
                        
                        // Confirm button (only when grace period expired)
                        if daysRemaining == 0 {
                            form(
                                action: .init(confirmAction.relativePath),
                                method: .post
                            ) {
                                Button(
                                    button: .init(type: .submit)
                                ) {
                                    TranslatedString(
                                        dutch: "Definitief Verwijderen",
                                        english: "Permanently Delete"
                                    )
                                }
                                .backgroundColor(.background.error)
                                .color(.text.primary.reverse())
                                .width(.percent(100))
                                .justifyContent(.center)
                            }
                            .id(Self.confirm_form_id)
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
                }
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Account Verwijdering",
                        english: "Account Deletion"
                    )
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.pagemodule_delete_pending_id)
            .width(.percent(100))
            
            // Only add confirmation dialog for the confirm form
            script {#"""
            document.addEventListener('DOMContentLoaded', function() {
                const confirmForm = document.getElementById('\#(Self.confirm_form_id)');
                
                if (confirmForm) {
                    confirmForm.addEventListener('submit', function(event) {
                        // Double confirmation for permanent deletion
                        const confirmed = confirm('\#(TranslatedString(
                            dutch: "Weet u zeker dat u uw account permanent wilt verwijderen? Dit kan niet ongedaan worden gemaakt.",
                            english: "Are you sure you want to permanently delete your account? This cannot be undone."
                        ))');
                        
                        if (!confirmed) {
                            event.preventDefault();
                        }
                    });
                }
            });
            """#}
        }
    }
}
