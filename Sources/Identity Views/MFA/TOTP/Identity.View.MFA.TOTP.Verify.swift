//
//  Identity.View.MFA.TOTP.Verify.swift
//  coenttb-identities
//
//  TOTP verification view during login
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

// MARK: - Helper Views

fileprivate struct VerifyCodeInput: HTML {
    let inputId: String
    
    var body: some HTML {
        VStack {
            input.text(
                name: "code",
                maxlength: 6,
                pattern: "[0-9]{6}",
                placeholder: "000000",
                spellcheck: false,
                required: true
            )
            .id(inputId)
            .autofocus(true)
            .autocorrect(.off)
            .padding(.rem(1))
            .fontSize(.rem(2))
            .fontFamily(.monospace)
            .textAlign(.center)
            .borderRadius(.rem(0.5))
            .border(width: .px(1), style: .solid, color: .background.primary)
            .width(.percent(100))
            .maxWidth(.rem(14))
            .margin(horizontal: .auto)
            .backgroundColor(.background.primary)
            .inlineStyle("letter-spacing", "0.75rem")
            .inlineStyle("text-indent", "0.75rem")
            .transition("border-color 0.2s, box-shadow 0.2s")
            .inlineStyle("outline", "none")
            .borderColor(.branding.primary, pseudo: .focus)
            .inlineStyle("box-shadow", "0 0 0 4px rgba(59, 130, 246, 0.15)", pseudo: .focus)
        }
        .marginBottom(.rem(1.5))
    }
}

fileprivate struct AttemptsWarning: HTML {
    let attempts: Int
    
    var body: some HTML {
        div {
            span { "⚠️ " }
            HTMLText("\(attempts) attempt\(attempts == 1 ? "" : "s") remaining")
        }
        .padding(.rem(0.75))
        .backgroundColor(.background.warning.map { $0.opacity(0.1) })
        .borderRadius(.rem(0.5))
        .border(width: .px(1), style: .solid, color: .background.warning.map { $0.opacity(0.3) })
        .color(.text.warning)
        .fontWeight(.medium)
        .textAlign(.center)
        .marginBottom(.rem(1.5))
    }
}

fileprivate struct VerifyButton: HTML {
    var body: some HTML {
        Button(
            button: .init(type: .submit)
        ) {
            "Verify"
        }
        .color(.text.primary.reverse())
        .backgroundColor(.branding.primary)
        .padding(vertical: .rem(0.875), horizontal: .rem(3))
        .borderRadius(.rem(0.5))
        .fontWeight(.medium)
        .fontSize(.rem(1.125))
        .width(.percent(100))
        .maxWidth(.rem(14))
        .margin(horizontal: .auto)
        .transition("background-color 0.2s, transform 0.1s")
        .backgroundColor(.branding.primary.map { $0.opacity(0.9) }, pseudo: .hover)
        .inlineStyle("transform", "scale(0.98)", pseudo: .active)
        .marginBottom(.rem(2))
    }
}

fileprivate struct AlternativeOptions: HTML {
    let useBackupCodeHref: URL?
    let cancelHref: URL
    
    var body: some HTML {
        HStack {
            if let backupHref = useBackupCodeHref {
                Link(href: .init(backupHref.relativePath)) {
                    "Use backup code"
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

extension Identity.MFA.TOTP.Verify {
    package struct View: HTML {
        let sessionToken: String
        let verifyAction: URL
        let useBackupCodeHref: URL?
        let cancelHref: URL
        let attemptsRemaining: Int?
        
        package init(
            sessionToken: String,
            verifyAction: URL,
            useBackupCodeHref: URL? = nil,
            cancelHref: URL,
            attemptsRemaining: Int? = nil
        ) {
            self.sessionToken = sessionToken
            self.verifyAction = verifyAction
            self.useBackupCodeHref = useBackupCodeHref
            self.cancelHref = cancelHref
            self.attemptsRemaining = attemptsRemaining
        }
        
        private static let form_id: String = "totp-verify-form"
        private static let code_input_id: String = "totp-verify-code"
        
        package var body: some HTML {
            PageModule(theme: .authenticationFlow) {
                form(
                    action: .init(verifyAction.relativePath),
                    method: .post
                ) {
                    VStack {
                        // Instructions
                        HTMLText("Enter the 6-digit code from your authenticator app")
                            .font(.body)
                            .color(.text.secondary)
                            .textAlign(.center)
                            .marginBottom(.rem(2))
                        
                        // Hidden fields for the verify endpoint
                        input.hidden(name: "sessionToken", value: .init(sessionToken))
                        input.hidden(name: "method", value: "totp")
                        
                        // Verification code input
                        VerifyCodeInput(inputId: Self.code_input_id)
                        
                        // Attempts remaining warning
                        if let attempts = attemptsRemaining, attempts <= 2 {
                            AttemptsWarning(attempts: attempts)
                        }
                        
                        // Submit button
                        VerifyButton()
                        
                        // Alternative options
                        AlternativeOptions(
                            useBackupCodeHref: useBackupCodeHref,
                            cancelHref: cancelHref
                        )
                    }
                }
                .id(Self.form_id)
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
                
                // Enhanced JavaScript with better UX
                script {
                    """
                    document.addEventListener('DOMContentLoaded', function() {
                        const codeInput = document.getElementById('\(Self.code_input_id)');
                        const form = document.getElementById('\(Self.form_id)');
                        let isSubmitting = false;
                        
                        if (codeInput && form) {
                            // Auto-submit when 6 digits entered
                            codeInput.addEventListener('input', function(e) {
                                // Remove non-digits
                                e.target.value = e.target.value.replace(/[^0-9]/g, '');
                                
                                if (e.target.value.length === 6 && !isSubmitting) {
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
                                const digits = pastedData.replace(/[^0-9]/g, '').substring(0, 6);
                                codeInput.value = digits;
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
                    "Verify Your Identity"
                }
            }
        }
    }
}
