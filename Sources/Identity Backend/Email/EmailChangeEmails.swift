//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/10/2024.
//

import IdentitiesTypes
//import Mailgun
import CoenttbEmail
import CoenttbHTML
import ServerFoundation

// MARK: - Email Change Messages Namespace

extension Identity.Email.Change {
    /// Namespace for email messages/templates related to email changes
    package enum Messages {}
}

// MARK: - Message Types

extension Identity.Email.Change.Messages {
    /// Top-level email change message types
    package enum Message {
        case request(Request)
        case confirmation(Confirmation)
    }
    
    /// Email messages related to email change requests
    package enum Request {
        case notification(Notification)
        
        package struct Notification: Sendable {
            package let currentEmail: EmailAddress
            package let newEmail: EmailAddress
            package let userName: String?
            
            package init(
                currentEmail: EmailAddress,
                newEmail: EmailAddress,
                userName: String?
            ) {
                self.currentEmail = currentEmail
                self.newEmail = newEmail
                self.userName = userName
            }
        }
    }
    
    /// Email messages related to email change confirmations
    package enum Confirmation {
        case request(Request)
        case notification(Notification)
        
        package struct Request: Sendable {
            package let verificationURL: URL
            package let currentEmail: EmailAddress
            package let newEmail: EmailAddress
            package let userName: String?
            
            package init(
                verificationURL: URL,
                currentEmail: EmailAddress,
                newEmail: EmailAddress,
                userName: String?
            ) {
                self.verificationURL = verificationURL
                self.currentEmail = currentEmail
                self.newEmail = newEmail
                self.userName = userName
            }
        }
        
        package enum Notification: Sendable {
            case currentEmail(Payload)
            case newEmail(Payload)
            
            package struct Payload: Sendable {
                package let currentEmail: EmailAddress
                package let newEmail: EmailAddress
                package let userName: String?
                
                package init(
                    currentEmail: EmailAddress,
                    newEmail: EmailAddress,
                    userName: String?
                ) {
                    self.currentEmail = currentEmail
                    self.newEmail = newEmail
                    self.userName = userName
                }
            }
        }
    }
}
//
//// MARK: - Mailgun Email Initializers
//
//extension Mailgun.Email {
//    package init(
//        business: BusinessDetails,
//        emailChangeMessage: Identities.Identity.Email.Change.Messages.Message
//    ) throws {
//        switch emailChangeMessage {
//        case .request(let request):
//            switch request {
//            case .notification(let notification):
//                self = try .init(
//                    business: business,
//                    emailChangeRequestNotification: notification
//                )
//            }
//            
//        case .confirmation(let confirmation):
//            switch confirmation {
//            case .request(let request):
//                self = try .init(
//                    business: business,
//                    emailChangeConfirmationRequest: request
//                )
//            case .notification(let notification):
//                self = try .init(
//                    business: business,
//                    emailChangeConfirmationNotification: notification
//                )
//            }
//        }
//    }
//}
//
//extension Mailgun.Email {
//    package init(
//        business: BusinessDetails,
//        emailChangeRequestNotification: Identities.Identity.Email.Change.Messages.Request.Notification
//    ) throws {
//        
//        let subject = TranslatedString(
//            dutch: "Belangrijk: Verzoek tot e-mailwijziging ontvangen",
//            english: "Important: Email Change Request Received"
//        )
//
//        self = try .init(
//            from: business.fromEmail,
//            to: [ emailChangeRequestNotification.currentEmail ],
//            subject: "\(business.name) | \(subject)",
//            text: nil
//        ) {
//            TableEmailDocument(
//                preheader: TranslatedString(
//                    dutch: "Er is een verzoek ingediend om je e-mailadres te wijzigen voor \(business.name)",
//                    english: "A request has been made to change your email address for \(business.name)"
//                ).description
//            ) {
//                tr {
//                    td {
//                        VStack(alignment: .start) {
//                            Header(3) {
//                                TranslatedString(
//                                    dutch: "Verzoek tot e-mailwijziging ontvangen",
//                                    english: "Email Change Request Received"
//                                )
//                            }
//
//                            CoenttbHTML.Paragraph {
//                                TranslatedString(
//                                    dutch: "We hebben een verzoek ontvangen om het e-mailadres voor je \(business.name) account te wijzigen van \(emailChangeRequestNotification.currentEmail) naar \(emailChangeRequestNotification.newEmail).",
//                                    english: "We received a request to change the email address for your \(business.name) account from \(emailChangeRequestNotification.currentEmail) to \(emailChangeRequestNotification.newEmail)."
//                                )
//                            }
//                            .padding(bottom: .extraSmall)
//                            .font(.body)
//
//                            CoenttbHTML.Paragraph {
//                                TranslatedString(
//                                    dutch: "Als je dit verzoek hebt gedaan, hoef je verder niets te doen. De wijziging wordt binnenkort doorgevoerd.",
//                                    english: "If you made this request, no further action is needed. The change will be processed shortly."
//                                )
//                            }
//                            .padding(bottom: .extraSmall)
//                            .font(.body)
//
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Als je dit verzoek niet hebt gedaan, neem dan onmiddellijk contact op met ons via \(business.supportEmail) om je account te beveiligen.",
//                                    english: "If you didn't request this change, please contact us immediately at \(business.supportEmail) to secure your account."
//                                )
//                            }
//                            .font(.footnote)
//                            .color(.text.secondary)
//                        }
//                        .padding(vertical: .small, horizontal: .medium)
//                    }
//                }
//            }
//                .backgroundColor(.background.primary.reverse())
//        }
//    }
//}
//
//extension Mailgun.Email {
//    package init(
//        business: BusinessDetails,
//        emailChangeConfirmationRequest: Identities.Identity.Email.Change.Messages.Confirmation.Request
//    ) throws {
//        let subject = TranslatedString(
//            dutch: "Verifieer je e-mailadres",
//            english: "Verify your email address"
//        )
//
//        self = try .init(
//            from: business.fromEmail,
//            to: [ emailChangeConfirmationRequest.newEmail ],
//            subject: "\(business.name) | \(subject)",
//            text: nil
//        ) {
//            TableEmailDocument(
//                preheader: TranslatedString(
//                    dutch: "Verifieer je nieuwe e-mailadres voor \(business.name)",
//                    english: "Verify your new email address for \(business.name)"
//                ).description
//            ) {
//                tr {
//                    td {
//                        VStack(alignment: .start) {
//                            Header(3) {
//                                TranslatedString(
//                                    dutch: "Verifieer je nieuwe e-mailadres",
//                                    english: "Verify your new email address"
//                                )
//                            }
//
//                            CoenttbHTML.Paragraph {
//                                TranslatedString(
//                                    dutch: "We hebben een verzoek ontvangen om het e-mailadres voor je \(business.name) account te wijzigen. Klik op de onderstaande knop om je nieuwe e-mailadres te verifiëren.",
//                                    english: "We received a request to change the email address for your \(business.name) account. Click the button below to verify your new email address."
//                                )
//                            }
//                            .padding(bottom: .extraSmall)
//                            .font(.body)
//
//                            Link(href: .init(value: emailChangeConfirmationRequest.verificationURL.absoluteString)) {
//                                TranslatedString(
//                                    dutch: "Verifieer e-mailadres",
//                                    english: "Verify email address"
//                                )
//                            }
//                            .color(.text.primary.reverse())
//                            .padding(bottom: .medium)
//
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Deze link verloopt binnen 1 uur om veiligheidsredenen.",
//                                    english: "This link will expire in 1 hour for security reasons."
//                                )
//                            }
//                            .font(.footnote)
//                            .color(.text.secondary)
//
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Als je geen wijziging van je e-mailadres hebt aangevraagd, kun je deze e-mail negeren.",
//                                    english: "If you didn't request an email address change, you can ignore this email."
//                                )
//                            }
//                            .font(.footnote)
//                            .color(.text.secondary)
//
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Voor hulp, neem contact op met ons via \(business.supportEmail).",
//                                    english: "For help, contact us at \(business.supportEmail)."
//                                )
//                            }
//                            .font(.footnote)
//                            .color(.text.secondary)
//                        }
//                        .padding(vertical: .small, horizontal: .medium)
//                    }
//                }
//            }
//                .backgroundColor(.background.primary.reverse())
//        }
//    }
//}
//
//extension Mailgun.Email {
//    package init(
//        business: BusinessDetails,
//        emailChangeConfirmationNotification: Identities.Identity.Email.Change.Messages.Confirmation.Notification
//    ) throws {
//        switch emailChangeConfirmationNotification {
//        case .currentEmail(let payload):
//            let subject = TranslatedString(
//                dutch: "Belangrijk: Je e-mailadres is gewijzigd",
//                english: "Important: Your email address has been changed"
//            )
//
//            self = try .init(
//                from: business.fromEmail,
//                to: [ payload.currentEmail ],
//                subject: "\(business.name) | \(subject)",
//                text: nil
//            ) {
//                TableEmailDocument(
//                    preheader: TranslatedString(
//                        dutch: "Je e-mailadres voor \(business.name) is gewijzigd",
//                        english: "Your email address for \(business.name) has been changed"
//                    ).description
//                ) {
//                    tr {
//                        td {
//                            VStack(alignment: .start) {
//                                Header(3) {
//                                    TranslatedString(
//                                        dutch: "Je e-mailadres is gewijzigd",
//                                        english: "Your email address has been changed"
//                                    )
//                                }
//
//                                CoenttbHTML.Paragraph {
//                                    TranslatedString(
//                                        dutch: "We willen je informeren dat het e-mailadres voor je \(business.name) account is gewijzigd van \(payload.currentEmail.rawValue) naar \(payload.newEmail.rawValue).",
//                                        english: "We're informing you that the email address for your \(business.name) account has been changed from \(payload.currentEmail.rawValue) to \(payload.newEmail.rawValue)."
//                                    )
//                                }
//                                .padding(bottom: .extraSmall)
//                                .font(.body)
//
//                                CoenttbHTML.Paragraph {
//                                    TranslatedString(
//                                        dutch: "Als je deze wijziging hebt aangevraagd, kun je deze e-mail als bevestiging beschouwen. Je kunt nu inloggen met je nieuwe e-mailadres.",
//                                        english: "If you requested this change, please consider this email as confirmation. You can now log in using your new email address."
//                                    )
//                                }
//                                .padding(bottom: .extraSmall)
//                                .font(.body)
//
//                                CoenttbHTML.Paragraph(.small) {
//                                    TranslatedString(
//                                        dutch: "Als je deze wijziging niet hebt aangevraagd, neem dan onmiddellijk contact op met ons via \(business.supportEmail) om je account te beveiligen.",
//                                        english: "If you didn't request this change, please contact us immediately at \(business.supportEmail) to secure your account."
//                                    )
//                                }
//                                .font(.footnote)
//                                .color(.text.secondary)
//                            }
//                            .padding(vertical: .small, horizontal: .medium)
//                        }
//                    }
//                }
//                    .backgroundColor(.background.primary.reverse())
//            }
//
//        case .newEmail(let payload):
//            let subject = TranslatedString(
//                dutch: "Je nieuwe e-mailadres is bevestigd",
//                english: "Your new email address is confirmed"
//            )
//
//            self = try .init(
//                from: business.fromEmail,
//                to: [ payload.newEmail ],
//                subject: "\(business.name) | \(subject)",
//                text: nil
//            ) {
//                TableEmailDocument(
//                    preheader: TranslatedString(
//                        dutch: "Je nieuwe e-mailadres voor \(business.name) is bevestigd",
//                        english: "Your new email address for \(business.name) is confirmed"
//                    ).description
//                ) {
//                    tr {
//                        td {
//                            VStack(alignment: .start) {
//                                Header(3) {
//                                    TranslatedString(
//                                        dutch: "Je nieuwe e-mailadres is bevestigd",
//                                        english: "Your new email address is confirmed"
//                                    )
//                                }
//
//                                CoenttbHTML.Paragraph {
//                                    TranslatedString(
//                                        dutch: "Welkom! We bevestigen dat dit e-mailadres (\(payload.newEmail.rawValue)) nu is gekoppeld aan je \(business.name) account. Je vorige e-mailadres was \(payload.currentEmail.rawValue).",
//                                        english: "Welcome! We confirm that this email address (\(payload.newEmail.rawValue)) is now associated with your \(business.name) account. Your previous email address was \(payload.currentEmail.rawValue)."
//                                    )
//                                }
//                                .padding(bottom: .extraSmall)
//                                .font(.body)
//
//                                CoenttbHTML.Paragraph {
//                                    TranslatedString(
//                                        dutch: "Je kunt nu inloggen op je account met dit nieuwe e-mailadres. Al je accountgegevens en voorkeuren blijven ongewijzigd.",
//                                        english: "You can now log in to your account using this new email address. All your account details and preferences remain unchanged."
//                                    )
//                                }
//                                .padding(bottom: .extraSmall)
//                                .font(.body)
//
//                                CoenttbHTML.Paragraph(.small) {
//                                    TranslatedString(
//                                        dutch: "Als je deze wijziging niet hebt aangevraagd of als je vragen hebt, neem dan contact op met ons via \(business.supportEmail).",
//                                        english: "If you didn't request this change or if you have any questions, please contact us at \(business.supportEmail)."
//                                    )
//                                }
//                                .font(.footnote)
//                                .color(.text.secondary)
//                            }
//                            .padding(vertical: .small, horizontal: .medium)
//                        }
//                    }
//                }
//                    .backgroundColor(.background.primary.reverse())
//            }
//        }
//    }
//}
