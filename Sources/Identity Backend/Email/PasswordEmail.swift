//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 17/10/2024.
//

import IdentitiesTypes
//import Mailgun
import CoenttbEmail
import CoenttbHTML
import ServerFoundation

package enum PasswordEmail {
    case reset(PasswordEmail.Reset)
    case change(PasswordEmail.Change)
}

extension PasswordEmail {
    package enum Reset {
        case request(PasswordEmail.Reset.Request)
        case confirmation(PasswordEmail.Reset.Confirmation)
    }

    package enum Change {
        case notification(PasswordEmail.Change.Notification)
    }
}

extension PasswordEmail.Reset {
    package struct Request: Sendable {
        package let resetUrl: URL
        package let userName: String?
        package let userEmail: EmailAddress

        package init(resetUrl: URL, userName: String?, userEmail: EmailAddress) {
            self.resetUrl = resetUrl
            self.userName = userName
            self.userEmail = userEmail
        }
    }

    package struct Confirmation: Sendable {
        package let userName: String?
        package let userEmail: EmailAddress

        package init(userName: String?, userEmail: EmailAddress) {
            self.userName = userName
            self.userEmail = userEmail
        }
    }
}

extension PasswordEmail.Change {
    package struct Notification: Sendable {
        package let userName: String?
        package let userEmail: EmailAddress

        package init(userName: String?, userEmail: EmailAddress) {
            self.userName = userName
            self.userEmail = userEmail
        }
    }
}
//
//extension Mailgun.Email {
//    package init(
//        business: BusinessDetails,
//        passwordEmail: PasswordEmail
//    ) throws {
//        switch passwordEmail {
//        case .reset(let reset):
//            switch reset {
//            case .request(let request):
//                self = try .init(
//                    business: business,
//                    passwordResetRequest: request
//                )
//            case .confirmation(let confirmation):
//                self = try .init(
//                    business: business,
//                    passwordResetConfirmation: confirmation
//                )
//            }
//        case .change(let change):
//            switch change {
//            case .notification(let notification):
//                self = try .init(
//                    business: business,
//                    passwordChangeNotification: notification
//                )
//            }
//        }
//    }
//}
//
//extension Mailgun.Email {
//    private init(
//        business: BusinessDetails,
//        passwordResetRequest: PasswordEmail.Reset.Request
//    ) throws {
//        let subject = TranslatedString(
//            dutch: "Reset je wachtwoord",
//            english: "Reset your password"
//        )
//
//        self = try .init(
//            from: business.fromEmail,
//            to: [ passwordResetRequest.userEmail ],
//            subject: "\(business.name) | \(subject)",
//            text: nil
//        ) {
//            TableEmailDocument(
//                preheader: TranslatedString(
//                    dutch: "Reset je wachtwoord voor \(business.name)",
//                    english: "Reset your password for \(business.name)"
//                ).description
//            ) {
//                tr {
//                    td {
//                        VStack(alignment: .start) {
//                            Header(3) {
//                                TranslatedString(
//                                    dutch: "Reset je wachtwoord",
//                                    english: "Reset your password"
//                                )
//                            }
//                            
//                            CoenttbHTML.Paragraph {
//                                TranslatedString(
//                                    dutch: "We hebben een verzoek ontvangen om het wachtwoord voor je \(business.name) account te resetten. Klik op de onderstaande knop om je wachtwoord te wijzigen.",
//                                    english: "We received a request to reset the password for your \(business.name) account. Click the button below to change your password."
//                                )
//                            }
//                            .padding(bottom: .extraSmall)
//                            .font(.body)
//                            
//                            Link(href: .init(value: passwordResetRequest.resetUrl.absoluteString)) {
//                                TranslatedString(
//                                    dutch: "Reset wachtwoord",
//                                    english: "Reset password"
//                                )
//                            }
//                            .color(.text.primary.reverse())
//                            .padding(bottom: .medium)
//                            
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Om veiligheidsredenen verloopt deze link binnen 1 uur.",
//                                    english: "This link will expire in 1 hour for security reasons."
//                                )
//                            }
//                            .font(.footnote)
//                            .color(.text.secondary)
//                            
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Als je geen wachtwoordreset hebt aangevraagd, kun je deze e-mail negeren.",
//                                    english: "If you didn't request a password reset, you can ignore this email."
//                                )
//                            }
//                            .font(.footnote)
//                            .color(.text.secondary)
//                            
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Voor hulp, neem contact op met ons op via \(business.supportEmail).",
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
//extension Mailgun.Email {
//    private init(
//        business: BusinessDetails,
//        passwordResetConfirmation: PasswordEmail.Reset.Confirmation
//    ) throws {
//        let subject = TranslatedString(
//            dutch: "Wachtwoord succesvol gereset",
//            english: "Password Successfully Reset"
//        )
//
//        self = try .init(
//            from: business.fromEmail,
//            to: [ passwordResetConfirmation.userEmail ],
//            subject: "\(business.name) | \(subject)",
//            text: nil
//        ) {
//            TableEmailDocument(
//                preheader: TranslatedString(
//                    dutch: "Je wachtwoord is succesvol gereset voor \(business.name)",
//                    english: "Your password has been successfully reset for \(business.name)"
//                ).description
//            ) {
//                tr {
//                    td {
//                        VStack(alignment: .start) {
//                            Header(3) {
//                                TranslatedString(
//                                    dutch: "Wachtwoord succesvol gereset",
//                                    english: "Password Successfully Reset"
//                                )
//                            }
//
//                            CoenttbHTML.Paragraph {
//                                TranslatedString(
//                                    dutch: "We bevestigen dat je wachtwoord voor je \(business.name) account succesvol is gereset.",
//                                    english: "We confirm that the password for your \(business.name) account has been successfully reset."
//                                )
//                            }
//                            .padding(bottom: .extraSmall)
//                            .font(.body)
//
//                            CoenttbHTML.Paragraph {
//                                TranslatedString(
//                                    dutch: "Je kunt nu inloggen met je nieuwe wachtwoord.",
//                                    english: "You can now log in using your new password."
//                                )
//                            }
//                            .padding(bottom: .extraSmall)
//                            .font(.body)
//
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Als je deze wijziging niet hebt aangevraagd, neem dan onmiddellijk contact op met ons via \(business.supportEmail) om je account te beveiligen.",
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
//    private init(
//        business: BusinessDetails,
//        passwordChangeNotification: PasswordEmail.Change.Notification
//    ) throws {
//        let subject = TranslatedString(
//            dutch: "Wachtwoord gewijzigd",
//            english: "Password Changed"
//        )
//
//        self = try .init(
//            from: business.fromEmail,
//            to: [ passwordChangeNotification.userEmail ],
//            subject: "\(business.name) | \(subject)",
//            text: nil
//        ) {
//            TableEmailDocument(
//                preheader: TranslatedString(
//                    dutch: "Je wachtwoord is gewijzigd voor \(business.name)",
//                    english: "Your password has been changed for \(business.name)"
//                ).description
//            ) {
//                tr {
//                    td {
//                        VStack(alignment: .start) {
//                            Header(3) {
//                                TranslatedString(
//                                    dutch: "Wachtwoord gewijzigd",
//                                    english: "Password Changed"
//                                )
//                            }
//
//                            CoenttbHTML.Paragraph {
//                                TranslatedString(
//                                    dutch: "We willen je informeren dat het wachtwoord voor je \(business.name) account zojuist is gewijzigd.",
//                                    english: "We're writing to inform you that the password for your \(business.name) account has just been changed."
//                                )
//                            }
//                            .padding(bottom: .extraSmall)
//                            .font(.body)
//
//                            CoenttbHTML.Paragraph {
//                                TranslatedString(
//                                    dutch: "Als je deze wijziging hebt aangevraagd, kun je deze e-mail als bevestiging beschouwen.",
//                                    english: "If you requested this change, please consider this email as confirmation."
//                                )
//                            }
//                            .padding(bottom: .extraSmall)
//                            .font(.body)
//
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Als je deze wijziging niet hebt aangevraagd, neem dan onmiddellijk contact op met ons via \(business.supportEmail) om je account te beveiligen.",
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
