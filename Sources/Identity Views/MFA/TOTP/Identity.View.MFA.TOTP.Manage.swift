//
//  Identity.View.MFA.TOTP.Manage.swift
//  coenttb-identities
//
//  TOTP management view for enabling/disabling and viewing backup codes
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

// MARK: - Helper Views

fileprivate struct StatusIndicator: HTML {
    let isEnabled: Bool
    
    var body: some HTML {
        div {
            if isEnabled {
//                span { "✅" }
//                    .fontSize(.rem(2))
                span { "✓" }
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
                    .color(.text.success)
                    .fontWeight(.bold)
                    .fontSize(.rem(1.25))
            } else {
                span { "⚠️" }
                    .fontSize(.rem(2))
                    .marginRight(.rem(0.75))
                
                span { "Disabled" }
                    .color(.text.warning)
                    .fontWeight(.bold)
                    .fontSize(.rem(1.25))
            }
        }
        .display(.flex)
        .alignItems(.center)
        .marginBottom(.rem(0.75))
    }
}

fileprivate struct BackupCodesSection: HTML {
    let remaining: Int
    let regenerateAction: URL?
    
    var body: some HTML {
        div {
            VStack {
                h3 { "Backup Codes" }
                    .fontWeight(.bold)
                    .marginBottom(.rem(0.5))
                
                VStack {
                    p {
                        HTMLText("\(remaining) backup code\(remaining == 1 ? "" : "s") remaining")
                    }
                    .color(remaining <= 2 ? .text.warning : .text.secondary)
                    .fontWeight(remaining <= 2 ? .bold : .normal)
                    
                    if remaining <= 2 {
                        p {
                            HTMLText("Consider regenerating your backup codes soon.")
                        }
                        .font(.body(.small))
                        .color(.text.warning)
                    }
                }
                .gap(.rem(0.25))
                .marginBottom(.rem(0.75))
                
                if let regenerateAction = regenerateAction {
                    form(
                        action: .init(regenerateAction.relativePath),
                        method: .post
                    ) {
                        Button(
                            button: .init(type: .submit)
                        ) {
                            "Regenerate Backup Codes"
                        }
                        .color(.text.secondary)
                        .backgroundColor(.background.secondary.map { $0.opacity(0.2) })
                        .padding(vertical: .rem(0.5), horizontal: .rem(1))
                        .borderRadius(.rem(0.375))
                        .border(width: .px(1), style: .solid, color: .background.primary)
                        .fontWeight(.medium)
                        .font(.body(.small))
                        .transition("background-color 0.2s")
                        .backgroundColor(.background.secondary.map { $0.opacity(0.5) }, pseudo: .hover)
                        .attribute("onclick", "return confirm('This will invalidate your existing backup codes. Continue?')")
                    }
                }
            }
        }
        .padding(.rem(1))
        .backgroundColor(.background.secondary.map { $0.opacity(0.1) })
        .borderRadius(.rem(0.5))
        .marginBottom(.rem(1.5))
    }
}

fileprivate struct DisableSection: HTML {
    let disableAction: URL
    
    var body: some HTML {
        div {
            VStack {
                h3 { "Disable Two-Factor Authentication" }
                    .fontWeight(.semiBold)
                    .color(.text.error)
                    .marginBottom(.rem(0.5))
                
                p {
                    HTMLText("Disabling 2FA will make your account less secure.")
                }
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
                    .color(.text.primary.reverse())
                    .backgroundColor(.background.error)
                    .padding(vertical: .rem(0.5), horizontal: .rem(1))
                    .borderRadius(.rem(0.375))
                    .fontWeight(.medium)
                    .font(.body(.small))
                    .transition("background-color 0.2s")
                    .backgroundColor(.background.error.map { $0.opacity(0.9) }, pseudo: .hover)
                    .attribute("onclick", "return confirm('Are you sure you want to disable two-factor authentication?')")
                }
            }
        }
        .border([.top], width: .px(1), style: .solid, color: .background.primary)
        .paddingTop(.rem(1.5))
    }
}

fileprivate struct EnableSection: HTML {
    let enableAction: URL
    
    var body: some HTML {
        HTMLMarkdown {"""
        Protect your account by requiring a verification code in addition to your password when signing in.
        
        ### How it works:
        
        1. Install an authenticator app on your phone
        1. Scan a QR code to link your account
        1. Enter a 6-digit code when you sign in
            
        """}
        VStack {
            
            p {
                HTMLText("Recommended apps: Google Authenticator, Authy, 1Password, Microsoft Authenticator")
            }
            .font(.body(.small))
            .color(.text.tertiary)
            .marginBottom(.rem(1.5))
            
            Link(href: .init(enableAction.relativePath)) {
                "Set Up Two-Factor Authentication"
            }
            .display(.inlineBlock)
            .color(.text.button)
            .backgroundColor(.background.button)
            .padding(vertical: .rem(0.75), horizontal: .rem(2))
            .borderRadius(.rem(0.5))
            .fontWeight(.medium)
            .textDecoration(TextDecoration.none)
            .transition("background-color 0.2s")
        }
    }
}

// Since Manage doesn't exist in swift-identities, we define it locally
extension Identity.MFA.TOTP {
    package enum Manage {}
}

extension Identity.MFA.TOTP.Manage {
    package struct View: HTML {
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
        
        package var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                VStack {
                    // Status card
                    div {
                        Header(3) { "Two-Factor Authentication Settings" }
                        
                        VStack(spacing: .rem(0.5)) {
                            StatusIndicator(isEnabled: isEnabled)
                            
                            p {
                                if isEnabled {
                                    HTMLText("Your account is protected with two-factor authentication.")
                                } else {
                                    HTMLText("Enable two-factor authentication for enhanced account security.")
                                }
                            }
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
                            if let disableAction = disableAction {
                                DisableSection(disableAction: disableAction)
                            }
                        } else {
                            // Enable option
                            if let enableAction = enableAction {
                                EnableSection(enableAction: enableAction)
                            }
                        }
                    }
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
                        .transition("color 0.2s")
                        .color(.branding.primary.map { $0.opacity(0.8) }, pseudo: .hover)
                    }
                    .textAlign(.center)
                }
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
            }
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

#Preview {
    HTMLDocument {
        Identity.MFA.TOTP.Manage.View(
            isEnabled: false,
            dashboardHref: URL(string: "/")!
        )
    }
}
#endif
