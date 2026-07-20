//
//  Identity.View.Delete.Cancelled.swift
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
    package enum Cancelled {}
}

extension Identity.Deletion.Cancelled {
    package struct View: HTML.View {
        let homeHref: URL

        package init(
            homeHref: URL
        ) {
            self.homeHref = homeHref
        }

        private static var cancellationId: String { "delete-cancellation-id" }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    div {
                        TranslatedString(
                            dutch: "✓ Verwijdering geannuleerd",
                            english: "✓ Deletion cancelled"
                        )
                    }
                    .css
                    .fontWeight(.bold)
                    .color(.text.success)
                    .textAlign(.center)
                    .margin(bottom: .rem(1))

                    Paragraph {
                        TranslatedString(
                            dutch:
                                "Uw verzoek om uw account te verwijderen is succesvol geannuleerd.",
                            english:
                                "Your request to delete your account has been successfully cancelled."
                        )
                    }
                    .css
                    .font(.body)
                    .textAlign(.center)
                    .margin(bottom: .rem(1))
                    .color(.text.primary)

                    Paragraph {
                        TranslatedString(
                            dutch: "Uw account blijft actief en al uw gegevens zijn behouden.",
                            english:
                                "Your account remains active and all your data has been preserved."
                        )
                    }
                    .css
                    .font(.body(.small))
                    .textAlign(.center)
                    .color(.text.secondary)
                    .margin(bottom: .rem(2))
                    .color(.text.primary)

                    Link(href: .init(homeHref.relativePath)) {
                        TranslatedString(
                            dutch: "Terug naar home",
                            english: "Back to Home"
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
                .textAlign(.center)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Verwijdering Geannuleerd",
                        english: "Deletion Cancelled"
                    )
                }
                .css
                .color(.text.primary)
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.cancellationId)
            .css
            .width(.percent(100))

            script {
                #"""
                    document.addEventListener('DOMContentLoaded', function() {
                        // Auto-redirect after 3 seconds
                        setTimeout(function() {
                            window.location.href = '\#(homeHref.absoluteString)';
                        }, 3000);
                    });
                """#
            }
        }
    }
}
