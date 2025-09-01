////
////  File.swift
////  coenttb-identities
////
////  Created by Coen ten Thije Boonkkamp on 04/10/2024.
////
//
//import Identities
//import Mailgun
//import CoenttbEmail
//import CoenttbHTML
//
//extension Mailgun.Email {
//    public static func requestEmailVerification(
//        verificationUrl: URL,
//        businessName: String,
//        supportEmail: EmailAddress,
//        from: EmailAddress,
//        to user: EmailAddress
//    ) throws -> Self {
//        let subject = TranslatedString(
//            dutch: "Verifieer je e-mailadres",
//            english: "Verify your email address"
//        )
//
//        return try .init(
//            from: from,
//            to: [ user ],
//            subject: "\(businessName) | \(subject)",
//            text: verificationUrl.absoluteString
//        ) {
//            TableEmailDocument(
//                preheader: TranslatedString(
//                    dutch: "Verifiëer je emailadres voor \(businessName)",
//                    english: "Verify your email for \(businessName)"
//                ).description
//            ) {
//                tr {
//                    td {
//                        VStack(alignment: .start) {
//                            Header(3) {
//                                TranslatedString(
//                                    dutch: "Verifiëer je emailadres",
//                                    english: "Verify your email address"
//                                )
//                            }
//
//                            CoenttbHTML.Paragraph {
//                                TranslatedString(
//                                    dutch: "Om de setup van je \(businessName) account te voltooien, bevestig alsjeblieft dat dit je e-mailadres is.",
//                                    english: "To continue setting up your \(businessName) account, please verify that this is your email address."
//                                )
//                            }
//                            .padding(bottom: .extraSmall)
//                            .font(.body)
//
//                            Link(href: .init(value: verificationUrl.absoluteString)) {
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
//                                    dutch: "Om veiligheidsredenen verloopt deze verificatielink binnen 24 uur.",
//                                    english: "This verification link will expire in 24 hours for security reasons."
//                                )
//                            }
//                            .font(.footnote)
//                            .color(.text.secondary)
//
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Als je deze aanvraag niet hebt gedaan, kun je deze e-mail negeren.",
//                                    english: "If you did not make this request, please disregard this email."
//                                )
//                            }
//                            .font(.footnote)
//                            .color(.text.secondary)
//
//                            CoenttbHTML.Paragraph(.small) {
//                                TranslatedString(
//                                    dutch: "Voor hulp, neem contact op met ons op via \(supportEmail).",
//                                    english: "For help, contact us at \(supportEmail)."
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
