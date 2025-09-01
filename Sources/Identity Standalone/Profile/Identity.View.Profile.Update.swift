//
//  Identity.View.Profile.Update.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web
import Identity_Views

extension Identity.View {
    public enum Profile {}
}

extension Identity.View.Profile {
    public struct Update: HTML {
        let currentDisplayName: String?
        let email: EmailAddress
        let updateDisplayNameAction: URL
        let dashboardHref: URL
        
        public init(
            currentDisplayName: String?,
            email: EmailAddress,
            updateDisplayNameAction: URL,
            dashboardHref: URL
        ) {
            self.currentDisplayName = currentDisplayName
            self.email = email
            self.updateDisplayNameAction = updateDisplayNameAction
            self.dashboardHref = dashboardHref
        }
        
        private static var pagemodule_profile_update_id: String { "pagemodule-profile-update" }
        private static var displayname_form_id: String { "form-update-displayname" }
        
        public var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    // Profile Information Section
                    div {
                        Header(4) {
                            TranslatedString(
                                dutch: "Profielinformatie",
                                english: "Profile Information"
                            )
                        }
                        .marginBottom(.rem(1))
                        
                        dl {
                            dt {
                                TranslatedString(
                                    dutch: "E-mailadres",
                                    english: "Email Address"
                                )
                            }
                            .fontWeight(.bold)
                            .marginBottom(.rem(0.25))
                            
                            dd { "\(email)" }
                                .marginLeft(.rem(2))
                                .marginBottom(.rem(1))
                                .color(.text.secondary)
                        }
                    }
                    .padding(.rem(1))
                    .backgroundColor(.background.primary)
                    .borderRadius(.medium)
                    .marginBottom(.rem(2))
                    
                    // Display Name Update Form
                    div {
                        Header(4) {
                            TranslatedString(
                                dutch: "Weergavenaam",
                                english: "Display Name"
                            )
                        }
                        .marginBottom(.rem(1))
                        
                        form(
                            action: .init(updateDisplayNameAction.relativePath),
                            method: .post
                        ) {
                            VStack {
                                Input(
                                    codingKey: Identity.API.Profile.UpdateDisplayName.CodingKeys.displayName,
                                    type: .text(
                                        .init(
                                            value: .init(currentDisplayName ?? ""),
                                            placeholder: .init(
                                                TranslatedString(
                                                    dutch: "Uw weergavenaam",
                                                    english: "Your display name"
                                                ).description
                                            )
                                        )
                                    )
                                )
                                .font(.body(.regular))
                                .padding(.rem(0.75))
                                .marginBottom(.rem(0.5))
                                
                                CoenttbHTML.Paragraph {
                                    TranslatedString(
                                        dutch: "Dit is hoe uw naam wordt weergegeven in de applicatie.",
                                        english: "This is how your name will appear throughout the application."
                                    )
                                }
                                .font(.body(.regular))
                                .color(.text.secondary)
                                .marginBottom(.rem(1))
                                
                                Button(
                                    button: .init(type: .submit)
                                ) {
                                    TranslatedString(
                                        dutch: "Weergavenaam Bijwerken",
                                        english: "Update Display Name"
                                    )
                                }
                                .backgroundColor(.background.primary)
                                .color(.text.primary.reverse())
                                .width(.percent(100))
                                .justifyContent(.center)
                            }
                        }
                        .id(Self.displayname_form_id)
                    }
                    
                    // Back to Dashboard Link
                    Link(href: .init(dashboardHref.relativePath)) {
                        TranslatedString(
                            dutch: "← Terug naar Dashboard",
                            english: "← Back to Dashboard"
                        ).description
                    }
                    .linkColor(.branding.primary)
                    .fontWeight(.medium)
                    .font(.body(.small))
                    .textAlign(.center)
                    .marginTop(.rem(1))
                }
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    TranslatedString(
                        dutch: "Profiel Bewerken",
                        english: "Edit Profile"
                    )
                }
                .display(.inlineBlock)
                .textAlign(.center)
            }
            .id(Self.pagemodule_profile_update_id)
            .width(.percent(100))
            
        }
    }
}
