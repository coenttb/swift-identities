//
//  Identity.View.MFA.BackupCodes.Verify.swift
//  coenttb-identities
//
//  Backup code verification view during MFA login
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

// MARK: - Helper Views

fileprivate struct BackupCodeInput: HTML {
    let inputId: String
    
    var body: some HTML {
        VStack {
            input.text(
                name: "code",
                maxlength: 8,
                pattern: "[A-Z0-9]{8}",
                placeholder: "XXXX-XXXX",
                spellcheck: false,
                required: true
            )
            .id(inputId)
            .autofocus(true)
            .autocorrect(.off)
            .autocapitalize(.characters)
            .padding(.rem(1))
            .fontSize(.rem(1.75))
            .fontFamily(.monospace)
            .textAlign(.center)
            .borderRadius(.rem(0.5))
            .border(width: .px(1), style: .solid, color: .background.primary)
            .width(.percent(100))
            .maxWidth(.rem(16))
            .margin(horizontal: .auto)
            .backgroundColor(.background.primary)
            .inlineStyle("letter-spacing", "0.25rem")
            .inlineStyle("text-indent", "0.25rem")
            .textTransform(.uppercase)
            .transition("border-color 0.2s, box-shadow 0.2s")
            .inlineStyle("outline", "none")
            .borderColor(.branding.primary, pseudo: .focus)
            .inlineStyle("box-shadow", "0 0 0 4px rgba(59, 130, 246, 0.15)", pseudo: .focus)
        }
        .marginBottom(.rem(1.5))
    }
}

fileprivate struct BackupCodeInstructions: HTML {
    var body: some HTML {
        VStack {
            HTMLText("Enter one of your backup codes")
                .font(.body)
                .color(.text.primary)
                .textAlign(.center)
                .marginBottom(.rem(0.5))
            
            HTMLText("Each backup code can only be used once")
                .font(.body(.small))
                .color(.text.secondary)
                .textAlign(.center)
        }
        .marginBottom(.rem(2))
    }
}

fileprivate struct VerifyBackupCodeButton: HTML {
    var body: some HTML {
        Button(
            button: .init(type: .submit)
        ) {
            "Verify Backup Code"
        }
        .color(.text.primary.reverse())
        .backgroundColor(.branding.primary)
        .padding(vertical: .rem(0.875), horizontal: .rem(2))
        .borderRadius(.rem(0.5))
        .fontWeight(.medium)
        .fontSize(.rem(1.125))
        .width(.percent(100))
        .maxWidth(.rem(16))
        .margin(horizontal: .auto)
        .transition("background-color 0.2s, transform 0.1s")
        .backgroundColor(.branding.primary.map { $0.opacity(0.9) }, pseudo: .hover)
        .inlineStyle("transform", "scale(0.98)", pseudo: .active)
        .marginBottom(.rem(2))
    }
}

fileprivate struct AlternativeBackupOptions: HTML {
    let useTotpHref: URL?
    let cancelHref: URL
    
    var body: some HTML {
        HStack {
            if let totpHref = useTotpHref {
                Link(href: .init(totpHref.relativePath)) {
                    "Use authenticator app"
                }
                .linkColor(.branding.primary)
                .font(.body(.small))
                .textDecoration(.underline)
                
                span { "•" }
                    .color(.text.tertiary)
                    .margin(horizontal: .rem(0.75))
            }
            
            Link(href: .init(cancelHref.relativePath)) {
                "Cancel"
            }
            .linkColor(.text.secondary)
            .font(.body(.small))
            .textDecoration(.underline)
            .color(.text.primary, pseudo: .hover)
        }
        .justifyContent(.center)
        .alignItems(.center)
    }
}

extension Identity.MFA.BackupCodes.Verify {
    public struct View: HTML {
        let sessionToken: String
        let verifyAction: URL
        let useTotpHref: URL?
        let cancelHref: URL
        let remainingCodes: Int?
        
        public init(
            sessionToken: String,
            verifyAction: URL,
            useTotpHref: URL? = nil,
            cancelHref: URL,
            remainingCodes: Int? = nil
        ) {
            self.sessionToken = sessionToken
            self.verifyAction = verifyAction
            self.useTotpHref = useTotpHref
            self.cancelHref = cancelHref
            self.remainingCodes = remainingCodes
        }
        
        private static let form_id: String = "backup-code-verify-form"
        private static let code_input_id: String = "backup-code-input"
        
        public var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                form(
                    action: .init(verifyAction.relativePath),
                    method: .post
                ) {
                    VStack {
                        // Instructions
                        BackupCodeInstructions()
                        
                        // Hidden fields for the verify endpoint
                        input.hidden(name: "sessionToken", value: .init(sessionToken))
                        input.hidden(name: "method", value: "backupCode")
                        
                        // Backup code input
                        BackupCodeInput(inputId: Self.code_input_id)
                        
                        // Remaining codes notice
                        if let remaining = remainingCodes, remaining > 0 {
                            div {
                                HTMLText("\(remaining) backup code\(remaining == 1 ? "" : "s") remaining")
                            }
                            .font(.body(.small))
                            .color(.text.secondary)
                            .textAlign(.center)
                            .marginBottom(.rem(1.5))
                        }
                        
                        // Submit button
                        VerifyBackupCodeButton()
                        
                        // Alternative options
                        AlternativeBackupOptions(
                            useTotpHref: useTotpHref,
                            cancelHref: cancelHref
                        )
                    }
                }
                .id(Self.form_id)
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
                
                // JavaScript for formatting and auto-submit
                script {
                    """
                    document.addEventListener('DOMContentLoaded', function() {
                        const codeInput = document.getElementById('\(Self.code_input_id)');
                        const form = document.getElementById('\(Self.form_id)');
                        let isSubmitting = false;
                        
                        if (codeInput && form) {
                            // Format input as user types
                            codeInput.addEventListener('input', function(e) {
                                let value = e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
                                
                                // Add hyphen after 4 characters
                                if (value.length > 4) {
                                    value = value.slice(0, 4) + '-' + value.slice(4, 8);
                                }
                                
                                e.target.value = value;
                                
                                // Auto-submit when 8 characters (plus hyphen) are entered
                                if (value.replace('-', '').length === 8 && !isSubmitting) {
                                    isSubmitting = true;
                                    // Visual feedback
                                    codeInput.style.borderColor = '#10b981';
                                    codeInput.style.backgroundColor = '#f0fdf4';
                                    
                                    // Auto-submit after a brief delay
                                    setTimeout(() => {
                                        form.submit();
                                    }, 300);
                                }
                            });
                            
                            // Paste handling
                            codeInput.addEventListener('paste', function(e) {
                                e.preventDefault();
                                const pastedData = (e.clipboardData || window.clipboardData).getData('text');
                                const cleaned = pastedData.toUpperCase().replace(/[^A-Z0-9]/g, '').substring(0, 8);
                                
                                // Format with hyphen
                                let formatted = cleaned;
                                if (cleaned.length > 4) {
                                    formatted = cleaned.slice(0, 4) + '-' + cleaned.slice(4);
                                }
                                
                                codeInput.value = formatted;
                                codeInput.dispatchEvent(new Event('input'));
                            });
                            
                            // Focus on load
                            codeInput.focus();
                            codeInput.select();
                        }
                    });
                    """
                }
            } title: {
                Header(3) {
                    "Use Backup Code"
                }
            }
        }
    }
}
