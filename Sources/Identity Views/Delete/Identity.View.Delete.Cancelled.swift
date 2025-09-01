//
//  Identity.View.Delete.Cancelled.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/09/2024.
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

extension Identity.Deletion {
    package enum Cancelled {}
}

extension Identity.Deletion.Cancelled {
    package struct View: HTML {
        let homeHref: URL
        
        package init(
            homeHref: URL
        ) {
            self.homeHref = homeHref
        }
        
        private static var cancellationId: String { "delete-cancellation-id" }
        
        package var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    div {
                        TranslatedString(
                            dutch: "✓ Verwijdering geannuleerd",
                            english: "✓ Deletion cancelled"
                        )
                    }
                    .fontWeight(.bold)
                    .color(.text.success)
                    .textAlign(.center)
                    .margin(bottom: .rem(1))
                    
                    CoenttbHTML.Paragraph {
                        TranslatedString(
                            dutch: "Uw verzoek om uw account te verwijderen is succesvol geannuleerd.",
                            english: "Your request to delete your account has been successfully cancelled."
                        )
                    }
                    .font(.body)
                    .textAlign(.center)
                    .margin(bottom: .rem(1))
                    
                    CoenttbHTML.Paragraph {
                        TranslatedString(
                            dutch: "Uw account blijft actief en al uw gegevens zijn behouden.",
                            english: "Your account remains active and all your data has been preserved."
                        )
                    }
                    .font(.body(.small))
                    .textAlign(.center)
                    .color(.text.secondary)
                    .margin(bottom: .rem(2))
                    
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
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
                .textAlign(.center)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Verwijdering Geannuleerd",
                        english: "Deletion Cancelled"
                    )
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.cancellationId)
            .width(.percent(100))
            
            script {#"""
                document.addEventListener('DOMContentLoaded', function() {
                    // Auto-redirect after 3 seconds
                    setTimeout(function() {
                        window.location.href = '\#(homeHref.absoluteString)';
                    }, 3000);
                });
            """#}
        }
    }
}
