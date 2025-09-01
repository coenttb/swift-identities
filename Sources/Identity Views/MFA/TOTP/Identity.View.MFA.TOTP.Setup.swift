//
//  Identity.View.MFA.TOTP.Setup.swift
//  coenttb-identities
//
//  TOTP setup view with QR code display and verification
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

// MARK: - Helper Views

fileprivate struct QRCodeSection: HTML {
    let qrCodeURL: URL
    
    var body: some HTML {
        div {
            img(
                src: "https://api.qrserver.com/v1/create-qr-code/?size=256x256&data=\(qrCodeURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                alt: "TOTP QR Code"
            )
            .display(.block)
            .margin(horizontal: .auto)
            .borderRadius(.rem(0.5))
        }
        .padding(.rem(2))
        .backgroundColor(.background.primary)
        .borderRadius(.rem(1))
        .inlineStyle("box-shadow", "0 4px 6px -1px rgba(0, 0, 0, 0.1)")
        .marginBottom(.rem(2))
    }
}

fileprivate struct ManualEntrySection: HTML {
    let manualEntryKey: String
    let secret: String
    
    var body: some HTML {
        details {
            summary { 
                "▸ Can't scan? Enter manually"
            }
            .font(.body(.small))
            .color(.branding.primary)
            .cursor(.pointer)
            
            div {
                p { "Enter this key in your authenticator app:" }
                    .font(.body(.small))
                    .color(.text.secondary)
                    .marginTop(.rem(1))
                
                div {
                    code { manualEntryKey }
                }
                .padding(.rem(1))
                .backgroundColor(.background.secondary.map { $0.opacity(0.5) })
                .borderRadius(.rem(0.5))
                .marginTop(.rem(0.5))
                .marginBottom(.rem(0.5))
                .wordBreak(.breakAll)
                .userSelect(.all)
                .textAlign(.center)
                .fontFamily(.monospace)
//                .font(.mono(.small))
                
                input.hidden(name: "secret", value: .init(secret))
            }
        }
        .marginBottom(.rem(2.5))
    }
}

fileprivate struct CodeInputSection: HTML {
    let inputId: String
    
    var body: some HTML {
        div {
            label(for: .init(inputId)) {
                "Enter the 6-digit code from your app"
            }
            .display(.block)
            .font(.body(.small))
            .fontWeight(.medium)
            .color(.text.primary)
            .marginBottom(.rem(0.75))
            
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
            .padding(.rem(0.75))
            .fontSize(.rem(1.5))
            .fontFamily(.monospace)
            .textAlign(.center)
            .borderRadius(.rem(0.5))
            .border(width: .px(1), style: .solid, color: .background.primary)
            .width(.percent(100))
            .maxWidth(.rem(12))
            .display(.block)
            .margin(horizontal: .auto)
            .backgroundColor(.background.primary)
            .inlineStyle("letter-spacing", "0.5rem")
            .inlineStyle("text-indent", "0.5rem")
            .inlineStyle("outline", "none")
        }
        .marginBottom(.rem(2.5))
    }
}

fileprivate struct ActionButtons: HTML {
    let cancelHref: URL
    
    var body: some HTML {
        div {
            button(type: .submit) {
                "Verify and Enable"
            }
            .color(.text.primary.reverse())
            .backgroundColor(.branding.primary)
            .padding(vertical: .rem(0.75), horizontal: .rem(2))
            .borderRadius(.rem(0.5))
            .fontWeight(.medium)
            .marginRight(.rem(1))
            .display(.inlineBlock)
            
            a(href: .url(cancelHref)) {
                "Cancel"
            }
            .color(.text.secondary)
            .padding(vertical: .rem(0.75), horizontal: .rem(2))
            .borderRadius(.rem(0.5))
            .border(width: .px(1), style: .solid, color: .background.primary)
            .fontWeight(.medium)
            .textDecoration(TextDecoration.none)
            .display(.inlineBlock)
        }
        .textAlign(.center)
    }
}

// Since Setup doesn't exist in swift-identities, we define it locally
extension Identity.MFA.TOTP {
    package enum Setup {}
}

extension Identity.MFA.TOTP.Setup {
    package struct View: HTML {
        let qrCodeURL: URL
        let secret: String
        let manualEntryKey: String
        let confirmAction: URL
        let cancelHref: URL
        
        package init(
            qrCodeURL: URL,
            secret: String,
            manualEntryKey: String,
            confirmAction: URL,
            cancelHref: URL
        ) {
            self.qrCodeURL = qrCodeURL
            self.secret = secret
            self.manualEntryKey = manualEntryKey
            self.confirmAction = confirmAction
            self.cancelHref = cancelHref
        }
        
        private static let form_id: String = "totp-setup-form"
        private static let code_input_id: String = "totp-code-input"
        private static let pagemodule_id: String = "totp-setup-pagemodule"
        
        package var body: some HTML {
            PageModule(theme: .mfaSetup) {
                form(
                    action: .init(confirmAction.relativePath),
                    method: .post
                ) {
                    VStack {
                        // Instructions
                        VStack {
                            HTMLText("Scan this QR code with your authenticator app")
                            HTMLText("(Google Authenticator, Authy, 1Password, etc.)")
                                .font(.body(.small))
                                .color(.text.secondary)
                        }
                        .gap(.rem(0.5))
                        .textAlign(.center)
                        .marginBottom(.rem(2))
                        
                        // QR Code
                        QRCodeSection(qrCodeURL: qrCodeURL)
                        
                        // Manual entry
                        ManualEntrySection(manualEntryKey: manualEntryKey, secret: secret)
                        
                        // Code input
                        CodeInputSection(inputId: Self.code_input_id)
                        
                        // Action buttons
                        ActionButtons(cancelHref: cancelHref)
                    }
                }
                .id(Self.form_id)
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
                
                // Enhanced JavaScript with AJAX submission
                script {
                    """
                    document.addEventListener('DOMContentLoaded', function() {
                        const codeInput = document.getElementById('\(Self.code_input_id)');
                        const form = document.getElementById('\(Self.form_id)');
                        let isSubmitting = false;
                        
                        // AJAX form submission
                        form.addEventListener('submit', async function(event) {
                            event.preventDefault();
                            
                            if (isSubmitting) return;
                            isSubmitting = true;
                            
                            const formData = new FormData(form);
                            const code = formData.get('code');
                            
                            try {
                                const response = await fetch(form.action, {
                                    method: 'POST',
                                    headers: {
                                        'Content-Type': 'application/x-www-form-urlencoded',
                                        'Accept': 'application/json'
                                    },
                                    body: new URLSearchParams({
                                        code: code
                                    }).toString()
                                });
                                
                                const data = await response.json();
                                
                                if (data.success && data.data && data.data.backupCodes) {
                                    // Replace the entire page module with backup codes display
                                    const pageModule = document.getElementById('\(Self.pagemodule_id)');
                                    pageModule.outerHTML = \(html: Identity.MFA.BackupCodes.Display.View(
                                        codes: ["PLACEHOLDER1", "PLACEHOLDER2", "PLACEHOLDER3", "PLACEHOLDER4", 
                                               "PLACEHOLDER5", "PLACEHOLDER6", "PLACEHOLDER7", "PLACEHOLDER8"],
                                        isRegeneration: false,
                                        dashboardHref: cancelHref
                                    ));
                                    
                                    // Replace placeholder codes with actual codes
                                    const actualCodes = data.data.backupCodes;
                                    // Update the codes in the display
                                    const codeElements = document.querySelectorAll('#backup-codes-list code');
                                    actualCodes.forEach((code, index) => {
                                        if (codeElements[index]) {
                                            const formatted = code.length === 8 ? 
                                                code.slice(0, 4) + '-' + code.slice(4) : code;
                                            codeElements[index].textContent = formatted;
                                        }
                                    });
                                    // Update the codes for download function
                                    window.backupCodesData = actualCodes;
                                } else {
                                    throw new Error(data.message || 'TOTP confirmation failed');
                                }
                            } catch (error) {
                                console.error('Error:', error);
                                // Show error message
                                const errorDiv = document.createElement('div');
                                errorDiv.textContent = error.message || 'Failed to enable TOTP. Please try again.';
                                errorDiv.style.color = 'red';
                                errorDiv.style.textAlign = 'center';
                                errorDiv.style.marginTop = '10px';
                                form.appendChild(errorDiv);
                                
                                // Reset form state
                                isSubmitting = false;
                                codeInput.value = '';
                                codeInput.style.borderColor = '';
                                codeInput.style.backgroundColor = '';
                            }
                        });
                        
                        // Format input as user types
                        codeInput.addEventListener('input', function(e) {
                            // Remove non-digits
                            e.target.value = e.target.value.replace(/[^0-9]/g, '');
                            
                            // Auto-submit when 6 digits are entered
                            if (e.target.value.length === 6 && !isSubmitting) {
                                // Visual feedback
                                codeInput.style.borderColor = '#10b981';
                                codeInput.style.backgroundColor = '#f0fdf4';
                                
                                // Small delay for user to see the complete code
                                setTimeout(() => {
                                    form.dispatchEvent(new Event('submit'));
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
                    });
                    """
                }
            } title: {
                Header(3) {
                    "Two-Factor Authentication Setup"
                }
            }
            .id(Self.pagemodule_id)
        }
    }
}
