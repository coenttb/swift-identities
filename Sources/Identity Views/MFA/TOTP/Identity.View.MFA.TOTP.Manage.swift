//
//  Identity.View.MFA.TOTP.Manage.swift
//  coenttb-identities
//
//  TOTP management view for enabling/disabling and viewing backup codes
//

import Foundation
import HTML
import IdentitiesTypes
import Server_Vapor
import Webpage

// MARK: - Helper Views

private struct StatusIndicator: HTML.View {
    let isEnabled: Bool

    var body: some HTML.View {
        div {
            if isEnabled {
                //                span { "✅" }
                //                    .fontSize(.rem(2))
                span { "✓" }
                    .css
                    .marginRight(.rem(0.75))
                    .fontSize(.rem(2))
                    .fontWeight(.bold)
                    .color(.text.success)
                    //                    .display(.inlineBlock)
                    .width(.rem(3.5))
                    .height(.rem(3.5))
                    .lineHeight(.rem(3.5))
                    .borderRadius(.percent(50))
                    .backgroundColor(.background.success)
                //                    .marginBottom(.rem(1.5))

                span { "Enabled" }
                    .css
                    .color(.text.success)
                    .fontWeight(.bold)
                    .fontSize(.rem(1.25))
            } else {
                span { "⚠️" }
                    .css
                    .fontSize(.rem(2))
                    .marginRight(.rem(0.75))

                span { "Disabled" }
                    .css
                    .color(.text.warning)
                    .fontWeight(.bold)
                    .fontSize(.rem(1.25))
            }
        }
        .css
        .display(.flex)
        .alignItems(.center)
        .marginBottom(.rem(0.75))
    }
}

private struct BackupCodesSection: HTML.View {
    let remaining: Int
    let regenerateAction: URL?

    var body: some HTML.View {
        div {
            VStack {
                h3 { "Backup Codes" }
                    .css
                    .fontWeight(.bold)
                    .marginBottom(.rem(0.5))

                VStack {
                    p {
                        HTML.Text("\(remaining) backup code\(remaining == 1 ? "" : "s") remaining")
                    }
                    .css
                    .color(remaining <= 2 ? .text.warning : .text.secondary)
                    .fontWeight(remaining <= 2 ? .bold : .normal)

                    if remaining <= 2 {
                        p {
                            HTML.Text("Consider regenerating your backup codes soon.")
                        }
                        .css
                        .font(.body(.small))
                        .color(.text.warning)
                    }
                }
                .css
                .gap(.rem(0.25))
                .marginBottom(.rem(0.75))

                if let regenerateAction {
                    form(
                        action: .init(regenerateAction.relativePath),
                        method: .post
                    ) {
                        Button(
                            button: .init(type: .submit)
                        ) {
                            "Regenerate Backup Codes"
                        }
                        .attribute(
                            "onclick",
                            "return confirm('This will invalidate your existing backup codes. Continue?')"
                        )
                        .css
                        .color(.text.secondary)
                        .backgroundColor(.background.secondary.map { $0.opacity(0.2) })
                        .padding(vertical: .rem(0.5), horizontal: .rem(1))
                        .borderRadius(.rem(0.375))
                        .border(width: .px(1), style: .solid, color: .background.primary)
                        .fontWeight(.medium)
                        .font(.body(.small))
                        .inlineStyle("transition", "background-color 0.2s")
                        .hover {
                            $0.backgroundColor(.background.secondary.map { $0.opacity(0.5) })
                        }
                    }
                }
            }
        }
        .css
        .padding(.rem(1))
        .backgroundColor(.background.secondary.map { $0.opacity(0.1) })
        .borderRadius(.rem(0.5))
        .marginBottom(.rem(1.5))
    }
}

private struct DisableSection: HTML.View {
    let disableAction: URL

    var body: some HTML.View {
        div {
            VStack {
                h3 { "Disable Two-Factor Authentication" }
                    .css
                    .fontWeight(.semiBold)
                    .color(.text.error)
                    .marginBottom(.rem(0.5))

                p {
                    HTML.Text("Disabling 2FA will make your account less secure.")
                }
                .css
                .color(.text.secondary)
                .marginBottom(.rem(0.75))

                form(
                    action: .init(disableAction.relativePath),
                    method: .post
                ) {
                    Button(
                        button: .init(type: .submit)
                    ) {
                        "Disable 2FA"
                    }
                    .attribute(
                        "onclick",
                        "return confirm('Are you sure you want to disable two-factor authentication?')"
                    )
                    .css
                    .color(.text.primary.reverse())
                    .backgroundColor(.background.error)
                    .padding(vertical: .rem(0.5), horizontal: .rem(1))
                    .borderRadius(.rem(0.375))
                    .fontWeight(.medium)
                    .font(.body(.small))
                    .inlineStyle("transition", "background-color 0.2s")
                    .hover {
                        $0.backgroundColor(.background.error.map { $0.opacity(0.9) })
                    }
                }
            }
        }
        .css
        .border([.top], width: .px(1), style: .solid, color: .background.primary)
        .paddingTop(.rem(1.5))
    }
}

private struct EnableSection: HTML.View {
    let enableAction: URL

    var body: some HTML.View {
        Markdown {
            """
            Protect your account by requiring a verification code in addition to your password when signing in.

            ### How it works:

            1. Install an authenticator app on your phone
            1. Scan a QR code to link your account
            1. Enter a 6-digit code when you sign in

            """
        }
        VStack {

            p {
                HTML.Text(
                    "Recommended apps: Google Authenticator, Authy, 1Password, Microsoft Authenticator"
                )
            }
            .css
            .font(.body(.small))
            .color(.text.tertiary)
            .marginBottom(.rem(1.5))

            Link(href: .init(enableAction.relativePath)) {
                "Set Up Two-Factor Authentication"
            }
            .css
            .display(.inlineBlock)
            .color(.text.button)
            .backgroundColor(.background.button)
            .padding(vertical: .rem(0.75), horizontal: .rem(2))
            .borderRadius(.rem(0.5))
            .fontWeight(.medium)
            .textDecoration(TextDecoration.none)
            .inlineStyle("transition", "background-color 0.2s")
        }
    }
}

// Since Manage doesn't exist in swift-identities, we define it locally
extension Identity.MFA.TOTP {
    package enum Manage {}
}

extension Identity.MFA.TOTP.Manage {
    package struct View: HTML.View {
        let isEnabled: Bool
        let backupCodesRemaining: Int?
        let enableAction: URL?
        let disableAction: URL?
        let regenerateBackupCodesAction: URL?
        let dashboardHref: URL

        package init(
            isEnabled: Bool,
            backupCodesRemaining: Int? = nil,
            enableAction: URL? = nil,
            disableAction: URL? = nil,
            regenerateBackupCodesAction: URL? = nil,
            dashboardHref: URL
        ) {
            self.isEnabled = isEnabled
            self.backupCodesRemaining = backupCodesRemaining
            self.enableAction = enableAction
            self.disableAction = disableAction
            self.regenerateBackupCodesAction = regenerateBackupCodesAction
            self.dashboardHref = dashboardHref
        }

        package var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    // Status card
                    div {
                        Header(3) { "Two-Factor Authentication Settings" }
                            .css
                            .color(.text.primary)

                        VStack(spacing: .rem(0.5)) {
                            StatusIndicator(isEnabled: isEnabled)

                            p {
                                if isEnabled {
                                    HTML.Text(
                                        "Your account is protected with two-factor authentication."
                                    )
                                } else {
                                    HTML.Text(
                                        "Enable two-factor authentication for enhanced account security."
                                    )
                                }
                            }
                            .css
                            .color(.text.secondary)
                        }

                        // Actions based on status
                        if isEnabled {
                            // Backup codes status
                            if let remaining = backupCodesRemaining {
                                BackupCodesSection(
                                    remaining: remaining,
                                    regenerateAction: regenerateBackupCodesAction
                                )
                            }

                            // Disable option
                            if let disableAction {
                                DisableSection(disableAction: disableAction)
                            }
                        } else {
                            // Enable option
                            if let enableAction {
                                EnableSection(enableAction: enableAction)
                            }
                        }
                    }
                    .css
                    .padding(.rem(1.5))
                    .backgroundColor(.background.primary)
                    .borderRadius(.rem(0.75))
                    .inlineStyle("box-shadow", "0 4px 6px -1px rgba(0, 0, 0, 0.1)")
                    .marginBottom(.rem(1.5))

                    // Back to dashboard
                    div {
                        Link(href: .init(dashboardHref.relativePath)) {
                            "← Back to Dashboard"
                        }
                        .linkColor(.branding.primary)
                        .textDecoration(.underline)
                        .inlineStyle("transition", "color 0.2s")
                        .hover {
                            $0.color(.branding.primary.map { $0.opacity(0.8) })
                        }
                    }
                    .css
                    .textAlign(.center)
                }
                .css
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .mobile { $0.maxWidth(.identityComponentMobile) }
                .margin(horizontal: .auto)
            }
        }
    }
}

#if canImport(SwiftUI)
    import SwiftUI

    #Preview {
        HTML.Document {
            Identity.MFA.TOTP.Manage.View(
                isEnabled: false,
                dashboardHref: URL(string: "/")!
            )
        }
    }
#endif
