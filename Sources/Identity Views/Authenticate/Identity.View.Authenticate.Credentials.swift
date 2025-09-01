//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 20/09/2024.
//

import Foundation
import IdentitiesTypes
import CoenttbHTML
import Coenttb_Web

extension Identity.Authentication.Credentials {
    package struct View: HTML {
        let passwordResetHref: URL
        let accountCreateHref: URL
        let loginFormAction: URL

        package init(
            passwordResetHref: URL,
            accountCreateHref: URL,
            loginFormAction: URL,
        ) {
            self.passwordResetHref = passwordResetHref
            self.accountCreateHref = accountCreateHref
            self.loginFormAction = loginFormAction
        }

        private static let form_id: String = "login-form-id"

        static func handleError(container: String, message: String) -> String {
            #"""
            console.error('Error:', error);
            const messageDiv = document.createElement('div');
            messageDiv.textContent = '\#(message)';
            messageDiv.style.color = 'red';
            messageDiv.style.textAlign = 'center';
            messageDiv.style.marginTop = '10px';
            \#(container).appendChild(messageDiv);
            """#
        }

        package var body: some HTML {

            PageModule(theme: .authenticationFlow) {
                form(
                    action: .init(loginFormAction.relativePath),
                    method: .post
                ) {
                    VStack {
                        Input(
                            codingKey: Identity.Authentication.Credentials.CodingKeys.username,
                            type: .email(
                                .init(
                                    placeholder: .init(String.email.capitalizingFirstLetter().description),
                                )
                            )
                        )
                        .focusOnPageLoad()
                        
                        div {
                            Input(
                                codingKey: Identity.Authentication.Credentials.CodingKeys.password,
                                type: .password(
                                    .init(
                                        placeholder: .init(String.password.capitalizingFirstLetter().description),
                                        required: true
                                    )
                                )
                            )
                            .id("password-input")
                            .inlineStyle("padding-right", "45px")
                            .width(.percent(100))
                            
                            div {
                                // Eye open icon (visible when password is hidden)
                                HTMLRaw(#"""
                                <svg id="eye-open" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                                    <circle cx="12" cy="12" r="3"></circle>
                                </svg>
                                """#)
                                
                                // Eye closed icon (visible when password is shown)
                                HTMLRaw(#"""
                                <svg id="eye-closed" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display: none;">
                                    <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
                                    <line x1="1" y1="1" x2="23" y2="23"></line>
                                </svg>
                                """#)
                            }
                            .id("password-toggle")
                            .position(.absolute)
                            .right(.px(12))
                            .top(.percent(50))
                            .inlineStyle("transform", "translateY(-50%)")
                            .cursor(.pointer)
                            .color(.gray)
                            .inlineStyle("transition", "color 0.2s")
                            .attribute("aria-label", "Toggle password visibility")
                            .attribute("role", "button")
                            .attribute("tabindex", "0")
                        }
                        .position(.relative)
                        .width(.percent(100))

                        Link(href: .init(passwordResetHref.relativePath)) {
                            String.forgot_password.capitalizingFirstLetter().questionmark
                        }
                        .linkColor(.branding.primary)
                        .font(.body(.small))
                        .display(.inlineBlock)

                        VStack {
                            Button(
                                button: .init(type: .submit)
                            ) {
                                String.continue.capitalizingFirstLetter()
                            }
                            .color(.text.primary.reverse())
                            .width(.percent(100))
                            .justifyContent(.center)

                            div {
                                HTMLText("\(String.dont_have_an_account.capitalizingFirstLetter().questionmark) ")
                                Link(href: .init(accountCreateHref.relativePath)) {
                                    String.signup.capitalizingFirstLetter()
                                }
                                .linkColor(.branding.primary)
                            }
                            .font(.body(.small))
                        }
                        .flexContainer(
                            justification: .center,
                            itemAlignment: .center,
                            media: .desktop
                        )
                        .width(.percent(100))
                    }
                }
                .id(Self.form_id)
                .width(.percent(100))
                .maxWidth(.identityComponentDesktop)
                .maxWidth(.identityComponentMobile, media: .mobile)
                .margin(horizontal: .auto)
            } title: {
                Header(3) {
                    String.welcome_back.capitalizingFirstLetter()
                }
            }
            .width(.percent(100))

            script {#"""
            // Add slide-in animation for new messages
            const style = document.createElement('style');
            style.textContent = `
                @keyframes slideIn {
                    0% { 
                        opacity: 0;
                        transform: translateY(-10px);
                    }
                    100% { 
                        opacity: 1;
                        transform: translateY(0);
                    }
                }
                @keyframes fadeIn {
                    0% { opacity: 0; }
                    100% { opacity: 1; }
                }
            `;
            document.head.appendChild(style);
            
            document.addEventListener('DOMContentLoaded', function() {
                const form = document.getElementById("\#(Self.form_id)");
                let countdownInterval = null;
                
                // Password visibility toggle - use name attribute selector as fallback
                let passwordInput = document.querySelector('input[name="\#(Identity.Authentication.Credentials.CodingKeys.password.rawValue)"]');
                if (!passwordInput) {
                    // Try by ID if name doesn't work
                    const wrapper = document.getElementById('password-input');
                    if (wrapper) {
                        passwordInput = wrapper.tagName === 'INPUT' ? wrapper : wrapper.querySelector('input');
                    }
                }
                
                const passwordToggle = document.getElementById('password-toggle');
                const eyeOpen = document.getElementById('eye-open');
                const eyeClosed = document.getElementById('eye-closed');
                let isPasswordVisible = false;
                
                if (passwordToggle && passwordInput && eyeOpen && eyeClosed) {
                    passwordToggle.addEventListener('click', function(e) {
                        e.preventDefault();
                        isPasswordVisible = !isPasswordVisible;
                        
                        if (isPasswordVisible) {
                            passwordInput.setAttribute('type', 'text');
                            eyeOpen.style.display = 'none';
                            eyeClosed.style.display = 'block';
                        } else {
                            passwordInput.setAttribute('type', 'password');
                            eyeOpen.style.display = 'block';
                            eyeClosed.style.display = 'none';
                        }
                    });
                    
                    // Add hover effect
                    passwordToggle.addEventListener('mouseenter', function() {
                        passwordToggle.style.color = '#495057';
                    });
                    
                    passwordToggle.addEventListener('mouseleave', function() {
                        passwordToggle.style.color = '#6c757d';
                    });
                    
                    // Allow keyboard activation
                    passwordToggle.addEventListener('keydown', function(event) {
                        if (event.key === 'Enter' || event.key === ' ') {
                            event.preventDefault();
                            passwordToggle.click();
                        }
                    });
                }

                function clearExistingMessages() {
                    const existingMessages = form.querySelectorAll('.error-message, .warning-message');
                    existingMessages.forEach(msg => msg.remove());
                    if (countdownInterval) {
                        clearInterval(countdownInterval);
                        countdownInterval = null;
                    }
                }

                function displayMessage(message, type = 'error', attemptsRemaining = null, retryAfter = null) {
                    clearExistingMessages();
                    
                    const messageDiv = document.createElement('div');
                    messageDiv.className = type + '-message';
                    
                    // Style based on type and attempts remaining
                    messageDiv.style.textAlign = 'center';
                    messageDiv.style.marginTop = '1.5rem';
                    messageDiv.style.padding = '0.875rem 1.25rem';
                    messageDiv.style.borderRadius = '0.5rem';
                    messageDiv.style.fontSize = '0.9375rem';
                    messageDiv.style.fontWeight = '500';
                    messageDiv.style.lineHeight = '1.5';
                    messageDiv.style.transition = 'all 0.3s ease';
                    messageDiv.style.backdropFilter = 'blur(8px)';
                    messageDiv.style.animation = 'slideIn 0.4s ease-out';
                    
                    // Build message content
                    let messageContent = message;
                    
                    // Add attempts remaining if available
                    if (attemptsRemaining !== null && attemptsRemaining > 0) {
                        const attemptText = attemptsRemaining === 1 ? 'attempt' : 'attempts';
                        messageContent += ` (${attemptsRemaining} ${attemptText} remaining)`;
                    }
                    
                    // Apply styling based on severity
                    if (attemptsRemaining !== null && attemptsRemaining > 0 && attemptsRemaining <= 2) {
                        // Warning style for low attempts
                        messageDiv.style.color = '\#(Color.text.warning.dark)';
                        messageDiv.style.backgroundColor = '\#(Color.background.error.light.opacity(0.3))';
                        messageDiv.style.border = '1px solid \#(Color.background.error.dark.opacity(0.3))';
                    } else if (type === 'warning') {
                        // Warning style
                        messageDiv.style.color = '\#(Color.text.warning.dark)';
                        messageDiv.style.backgroundColor = '\#(Color.background.warning.light.opacity(0.3))';
                        messageDiv.style.border = '1px solid \#(Color.background.warning.dark.opacity(0.3))';
                    } else {
                        // Error style (default)
                        messageDiv.style.color = '\#(Color.text.error.dark)';
                        messageDiv.style.backgroundColor = '\#(Color.background.highlighted.light.opacity(0.3))';
                        messageDiv.style.border = '1px solid \#(Color.background.highlighted.dark.opacity(0.3))';
                    }
                    
                    // Handle rate limit with countdown
                    if (retryAfter !== null && retryAfter > 0) {
                        let remainingSeconds = retryAfter;
                        
                        function updateCountdown() {
                            if (remainingSeconds > 0) {
                                const minutes = Math.floor(remainingSeconds / 60);
                                const seconds = remainingSeconds % 60;
                                const timeDisplay = minutes > 0 
                                    ? `${minutes}:${seconds.toString().padStart(2, '0')}` 
                                    : `${remainingSeconds} second${remainingSeconds !== 1 ? 's' : ''}`;
                                messageDiv.innerHTML = `Too many attempts. Please try again in <strong>${timeDisplay}</strong>`;
                                remainingSeconds--;
                            } else {
                                clearInterval(countdownInterval);
                                messageDiv.textContent = 'You can try again now';
                                messageDiv.style.color = '\#(Color.text.success.dark)';
                                messageDiv.style.backgroundColor = '\#(Color.background.success.light.opacity(0.3))';
                                messageDiv.style.border = '1px solid \#(Color.background.success.dark.opacity(0.3))';
                                // Re-apply fade animation for the status change
                                messageDiv.style.animation = 'fadeIn 0.5s ease-out';
                            }
                        }
                        
                        updateCountdown();
                        countdownInterval = setInterval(updateCountdown, 1000);
                    } else {
                        messageDiv.textContent = messageContent;
                    }
                    
                    form.appendChild(messageDiv);
                }

                form.addEventListener('submit', async function(event) {
                    event.preventDefault();
                    clearExistingMessages();

                    const formData = new FormData(form);
                    const email = formData.get('\#(Identity.Authentication.Credentials.CodingKeys.username.rawValue)');
                    const password = formData.get('\#(Identity.Authentication.Credentials.CodingKeys.password.rawValue)');

                    try {
                        const response = await fetch(form.action, {
                            method: form.method,
                            headers: {
                                'Content-Type': 'application/x-www-form-urlencoded',
                                'Accept': 'application/json'
                            },
                            body: new URLSearchParams({
                                 \#(Identity.Authentication.Credentials.CodingKeys.username.rawValue): email,
                                 \#(Identity.Authentication.Credentials.CodingKeys.password.rawValue): password
                            }).toString()
                        });

                        // Always try to parse the response as JSON
                        let data;
                        try {
                            data = await response.json();
                        } catch (e) {
                            // If JSON parsing fails, create a basic error response
                            data = { success: false, error: { message: 'Login failed. Please try again.' } };
                        }

                        // Check for MFA required response
                        if (response.ok && data.success && data.data && data.data.mfaRequired) {
                            // MFA is required - extract data from nested structure
                            const mfaData = data.data;
                            const sessionToken = mfaData.sessionToken;
                            const availableMethods = mfaData.availableMethods || ['totp'];
                            
                            // For now, we only support TOTP
                            if (availableMethods.includes('totp')) {
                                // Redirect to MFA verification page with session token as query parameter
                                const mfaUrl = new URL('/mfa/verify', window.location.origin);
                                mfaUrl.searchParams.set('sessionToken', sessionToken);
                                mfaUrl.searchParams.set('attemptsRemaining', mfaData.attemptsRemaining || 3);
                                window.location.href = mfaUrl.toString();
                            } else {
                                displayMessage('MFA method not supported', 'error');
                            }
                        } else if (response.ok && data.success) {
                            // Redirect URL is nested in data.data
                            const redirectUrl = data.data?.redirectUrl || data.redirectUrl || '/';
                            window.location.href = redirectUrl;
                        } else {
                            // Handle both successful responses with success: false and error responses
                            const error = data.error || {};
                            const message = error.message || 'Login failed. Please try again.';
                            const code = error.code || 'AUTH_ERROR';
                            const attemptsRemaining = data.attemptsRemaining;
                            const retryAfter = data.retryAfter;
                            
                            // Check response status for rate limiting
                            if (response.status === 429 || code === 'RATE_LIMIT') {
                                // For rate limit, parse Retry-After header if retryAfter not in body
                                const retryAfterValue = retryAfter || parseInt(response.headers.get('Retry-After') || '60');
                                displayMessage('Too many attempts. Please try again later.', 'error', null, retryAfterValue);
                            } else if (code === 'INVALID_CREDENTIALS' || response.status === 401) {
                                displayMessage(message, 'error', attemptsRemaining);
                            } else {
                                displayMessage(message, 'error', attemptsRemaining);
                            }
                        }

                    } catch (error) {
                        console.error('Error:', error);
                        displayMessage('An error occurred. Please try again.', 'error');
                    }
                });
            });
            """#}

        }
    }
}

