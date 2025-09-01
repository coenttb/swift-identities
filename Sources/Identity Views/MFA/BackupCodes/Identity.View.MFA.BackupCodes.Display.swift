//
//  Identity.View.MFA.BackupCodes.Display.swift
//  coenttb-identities
//
//  Display backup codes after MFA setup or regeneration
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

// MARK: - Helper Components

fileprivate struct BackupCodesHeader: HTML {
    let isRegeneration: Bool
    
    var body: some HTML {
        div {
            div {
                span { "🔐" }
                    .fontSize(.rem(3))
                    .marginBottom(.rem(1))
            }
            .textAlign(.center)
            
            Header(2) {
                if isRegeneration {
                    "New Backup Codes Generated"
                } else {
                    "Save Your Backup Codes"
                }
            }
            .textAlign(.center)
            .marginBottom(.rem(1))
        }
    }
}

fileprivate struct BackupCodesWarning: HTML {
    let isRegeneration: Bool
    
    var body: some HTML {
        div {
            p {
                if isRegeneration {
                    HTMLText("Your old backup codes have been invalidated. Save these new codes in a secure location.")
                } else {
                    HTMLText("Save these backup codes in a secure location. Each code can only be used once to access your account if you lose your authenticator app.")
                }
            }
            .color(.text.warning)
            .backgroundColor(.background.warning.map { $0.opacity(0.1) })
            .padding(.rem(1))
            .borderRadius(.rem(0.5))
            .border(width: .px(1), style: .solid, color: .background.warning)
            .marginBottom(.rem(1.5))
        }
    }
}

fileprivate struct BackupCodeItem: HTML {
    let index: Int
    let code: String
    
    var body: some HTML {
        div {
            span { "\(index + 1)." }
                .color(.text.tertiary)
                .marginRight(.rem(0.5))
                .fontWeight(.medium)
            
            HTMLElementTypes.Code { formatCode(code) }
                .fontFamily(.monospace)
                .fontSize(.rem(1.125))
                .letterSpacing(.rem(0.05))
                .fontWeight(.medium)
        }
        .padding(.rem(0.75))
        .backgroundColor(.background.secondary.map { $0.opacity(0.1) })
        .borderRadius(.rem(0.375))
        .marginBottom(.rem(0.5))
    }
    
    private func formatCode(_ code: String) -> String {
        // Format as XXXX-XXXX if it's 8 characters
        if code.count == 8 {
            let midIndex = code.index(code.startIndex, offsetBy: 4)
            return "\(code[..<midIndex])-\(code[midIndex...])"
        }
        return code
    }
}

fileprivate struct BackupCodesGrid: HTML {
    let codes: [String]
    
    var body: some HTML {
        div {
            div {
                for (index, code) in codes.enumerated() {
                    BackupCodeItem(index: index, code: code)
                }
            }
            .display(.grid)
            .inlineStyle("grid-template-columns", "1fr 1fr")
            .gap(.rem(0.75))
            .marginBottom(.rem(1.5))
        }
        .id("backup-codes-list")
    }
}

fileprivate struct BackupCodesActions: HTML {
    var body: some HTML {
        VStack {
            // Download button
            Button(
                button: .init(
                    type: .button
                )
            ) {
                "Download Codes"
            }
            .attribute("onclick", "downloadBackupCodes()")
            .display(.block)
            .width(.percent(100))
            .color(.text.button)
            .backgroundColor(.background.button)
            .padding(vertical: .rem(0.75), horizontal: .rem(1.5))
            .borderRadius(.rem(0.5))
            .fontWeight(.medium)
            .textAlign(.center)
            .cursor(.pointer)
            .transition("background-color 0.2s")
            .marginBottom(.rem(1))
            
            // Print button
            Button(
                button: .init(
                    type: .button
                )
            ) {
                "Print Codes"
            }
            .attribute("onclick", "window.print()")
            .display(.block)
            .width(.percent(100))
            .color(.text.secondary)
            .backgroundColor(.background.secondary.map { $0.opacity(0.2) })
            .padding(vertical: .rem(0.75), horizontal: .rem(1.5))
            .borderRadius(.rem(0.5))
            .fontWeight(.medium)
            .textAlign(.center)
            .cursor(.pointer)
            .border(width: .px(1), style: .solid, color: .background.primary)
            .transition("background-color 0.2s")
            .backgroundColor(.background.secondary.map { $0.opacity(0.4) }, pseudo: .hover)
            .marginBottom(.rem(1.5))
        }
    }
}

fileprivate struct BackupCodesConfirmation: HTML {
    let dashboardHref: URL
    
    var body: some HTML {
        VStack {
            // Confirmation checkbox
            div {
                label {
                    input(
                        type: .checkbox
                    )
                    .id("codes-saved-checkbox")
                    .attribute("onchange", "toggleContinueButton()")
                    .marginRight(.rem(0.5))
                    
                    span { "I have saved my backup codes in a secure location" }
                        .color(.text.primary)
                }
                .display(.flex)
                .alignItems(.center)
                .marginBottom(.rem(1.5))
            }
            
            // Continue button (disabled initially)
            Link(
                href: .init(dashboardHref.relativePath)
            ) {
                "Continue to Dashboard"
            }
            .id("continue-button")
            .class("disabled-link")
            .display(.block)
            .color(.text.tertiary)
            .backgroundColor(.background.secondary.map { $0.opacity(0.1) })
            .padding(vertical: .rem(0.75), horizontal: .rem(2))
            .borderRadius(.rem(0.5))
            .fontWeight(.medium)
            .textAlign(.center)
            .textDecoration(TextDecoration.none)
            .pointerEvents(PointerEvents.none)
            .opacity(0.5)
            .transition("all 0.2s")
        }
    }
}

fileprivate struct BackupCodesScript: HTML {
    let codes: [String]
    
    var body: some HTML {
        script {
            """
            function formatCodeForDownload(code) {
                // Format as XXXX-XXXX if it's 8 characters
                if (code.length === 8) {
                    return code.slice(0, 4) + '-' + code.slice(4);
                }
                return code;
            }
            
            function downloadBackupCodes() {
                console.log('Download button clicked');
                // Use window.backupCodesData if available (set by AJAX), otherwise use static codes
                const codes = window.backupCodesData || \(codesAsJSON());
                console.log('Codes to download:', codes);
                const formattedCodes = codes.map((code, index) => 
                    `${index + 1}. ${formatCodeForDownload(code)}`
                ).join('\\n');
                console.log('Formatted codes:', formattedCodes);
                
                const content = `Two-Factor Authentication Backup Codes\nGenerated: ${new Date().toLocaleDateString()}\n\nIMPORTANT: Keep these codes in a secure location.\nEach code can only be used once.\n\n${formattedCodes}\n\nIf you lose access to your authenticator app, you can use\none of these codes to sign in to your account.`;
                
                const blob = new Blob([content], { type: 'text/plain' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = 'backup-codes.txt';
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
            }
            
            function toggleContinueButton() {
                const checkbox = document.getElementById('codes-saved-checkbox');
                const button = document.getElementById('continue-button');
                
                if (checkbox.checked) {
                    button.classList.remove('disabled-link');
                    button.style.pointerEvents = 'auto';
                    button.style.opacity = '1';
                    button.style.backgroundColor = 'var(--color-background-button)';
                    button.style.color = 'var(--color-text-button)';
                } else {
                    button.classList.add('disabled-link');
                    button.style.pointerEvents = 'none';
                    button.style.opacity = '0.5';
                    button.style.backgroundColor = 'rgba(var(--color-background-secondary-rgb), 0.1)';
                    button.style.color = 'var(--color-text-tertiary)';
                }
            }
            """
        }
    }
    
    private func codesAsJSON() -> String {
        let jsonCodes = codes.map { "\"\($0)\"" }.joined(separator: ", ")
        return "[\(jsonCodes)]"
    }
}

// MARK: - Main Content Container

fileprivate struct MainContent: HTML {
    let codes: [String]
    let isRegeneration: Bool
    let dashboardHref: URL
    
    var body: some HTML {
        VStack {
            BackupCodesHeader(isRegeneration: isRegeneration)
            BackupCodesWarning(isRegeneration: isRegeneration)
            BackupCodesGrid(codes: codes)
            BackupCodesActions()
            BackupCodesConfirmation(dashboardHref: dashboardHref)
        }
        .width(.percent(100))
        .maxWidth(.identityComponentDesktop)
        .maxWidth(.identityComponentMobile, media: .mobile)
        .margin(horizontal: .auto)
        .padding(.rem(1.5))
        .backgroundColor(.background.primary)
        .borderRadius(.rem(0.75))
        .inlineStyle("box-shadow", "0 4px 6px -1px rgba(0, 0, 0, 0.1)")
    }
}

// MARK: - Main Display Component

// Since Display doesn't exist in swift-identities, we define it locally
extension Identity.MFA.BackupCodes {
    public enum Display {}
}

extension Identity.MFA.BackupCodes.Display {
    public struct View: HTML {
        let codes: [String]
        let isRegeneration: Bool
        let dashboardHref: URL
        
        public init(
            codes: [String],
            isRegeneration: Bool = false,
            dashboardHref: URL
        ) {
            self.codes = codes
            self.isRegeneration = isRegeneration
            self.dashboardHref = dashboardHref
        }
        
        public var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                MainContent(
                    codes: codes,
                    isRegeneration: isRegeneration,
                    dashboardHref: dashboardHref
                )
                
                // Include the JavaScript for download and toggle functionality
                BackupCodesScript(codes: codes)
            }
        }
    }
}
