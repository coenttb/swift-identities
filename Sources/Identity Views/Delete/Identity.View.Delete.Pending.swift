//
//  Identity.View.Delete.Pending.swift
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
    package enum Pending {}
}

extension Identity.Deletion.Pending {
    package struct View: HTML.View {
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

        private static var pageModuleDeletePendingID: String { "pagemodule-delete-pending" }
        private static var cancelFormID: String { "form-cancel-deletion" }
        private static var confirmFormID: String { "form-confirm-deletion" }

        package var body: some HTML.View {
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
                    .css
                    .fontWeight(.medium)
                    .color(daysRemaining > 0 ? .text.warning : .text.error)
                    .textAlign(.center)
                    .margin(bottom: .rem(1))

                    Paragraph {
                        if daysRemaining > 0 {
                            TranslatedString(
                                dutch: "Uw account wordt over \(daysRemaining) dagen verwijderd.",
                                english: "Your account will be deleted in \(daysRemaining) days."
                            )
                        } else {
                            TranslatedString(
                                dutch:
                                    "De bedenktijd is verstreken. U kunt nu de verwijdering bevestigen.",
                                english:
                                    "The grace period has expired. You can now confirm the deletion."
                            )
                        }
                    }
                    .css
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
                        .css
                        .margin(bottom: .rem(0.5))
                        .color(.text.primary)

                        Paragraph {
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
                        .css
                        .font(.body(.small))
                    }
                    .css
                    .padding(.rem(1))
                    .backgroundColor(
                        daysRemaining > 0
                            ? .background.warning.map { $0.opacity(0.3) }
                            : .background.error.map { $0.opacity(0.3) }
                    )
                    .borderRadius(.rem(0.5))
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
                            .css
                            .backgroundColor(.background.success)
                            .color(.text.primary.reverse())
                            .width(.percent(100))
                            .justifyContent(.center)
                        }
                        .id(Self.cancelFormID)

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
                                .css
                                .backgroundColor(.background.error)
                                .color(.text.primary.reverse())
                                .width(.percent(100))
                                .justifyContent(.center)
                            }
                            .id(Self.confirmFormID)
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
                    .css
                    .desktop {
                        $0.flexContainer(
                            justification: .center,
                            itemAlignment: .center
                        )
                    }
                    .width(.percent(100))
                }
                .css
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .mobile { $0.maxWidth(.identityComponentMobile) }
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Account Verwijdering",
                        english: "Account Deletion"
                    )
                }
                .css
                .display(.inlineBlock)
                .textAlign(.center)
                .color(.text.primary)
            }
            .id(Self.pageModuleDeletePendingID)
            .css
            .width(.percent(100))

            // Only add confirmation dialog for the confirm form
            script {
                #"""
                document.addEventListener('DOMContentLoaded', function() {
                    const confirmForm = document.getElementById('\#(Self.confirmFormID)');

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
                """#
            }
        }
    }
}
