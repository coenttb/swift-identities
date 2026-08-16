//
//  Identity.OAuth.Callback.View.swift
//  coenttb-identities
//
//  OAuth callback processing view
//

import Foundation
import HTML
import IdentitiesTypes
import Language
import Translating
import Webpage

extension Identity.OAuth.Callback {
    public struct View: HTML.View {
        let provider: String
        let redirectUrl: (Identity.ID) async throws -> URL

        public init(
            provider: String,
            redirectUrl: @escaping (Identity.ID) async throws -> URL
                // swiftlint:disable:previous typed_throws_required
        ) {
            self.provider = provider
            self.redirectUrl = redirectUrl
        }

        @HTML.Builder
        var hiddenInputs: some HTML.View {
            input.hidden(name: "code", value: "")
                .id("fallback-code")
            input.hidden(name: "state", value: "")
                .id("fallback-state")

            input.hidden(name: "provider", value: .init(provider))
        }

        public var body: some HTML.View {
            PageModule(theme: .authenticationFlow) {
                VStack(alignment: .center) {
                    // Loading spinner
                    div {
                        div {
                            // CSS spinner
                            div {}
                                .css
                                .width(.px(50))
                                .height(.px(50))
                                .border(width: .px(5), style: .solid, color: .gray300)
                                .borderTopColor(.blue500)
                                .borderRadius(.percent(50))
                                .inlineStyle("animation", "spin 1s linear infinite")
                        }
                        .css
                        .marginBottom(.large)

                        // Add keyframes for spinner animation
                        Style {
                            """
                            @keyframes spin {
                                0% { transform: rotate(0deg); }
                                100% { transform: rotate(360deg); }
                            }
                            """
                        }
                    }

                    // Processing message
                    h2 {
                        TranslatedString(
                            dutch: "Verwerken...",
                            english: "Processing..."
                        )
                    }
                    .css
                    .fontSize(.large)
                    .marginBottom(.medium)

                    // Provider info
                    p {
                        TranslatedString(
                            dutch: "We verwerken je \(provider) inloggegevens.",
                            english: "Processing your \(provider) authentication."
                        )
                    }
                    .css
                    .color(.gray600)
                    .marginBottom(.small)

                    p {
                        TranslatedString(
                            dutch: "Je wordt automatisch doorgestuurd...",
                            english: "You will be redirected automatically..."
                        )
                    }
                    .css
                    .fontSize(.rem(0.9))
                    .color(.gray500)

                    // JavaScript for auto-submission
                    script {
                        """
                        // Auto-submit the OAuth callback to the API endpoint
                        (function() {
                            // Get the current URL parameters
                            const urlParams = new URLSearchParams(window.location.search);
                            const code = urlParams.get('code');
                            const state = urlParams.get('state');
                            const provider = urlParams.get('provider') || '\(provider)';

                            if (code && state) {
                                // Make API call to process the OAuth callback
                                fetch('/api/oauth/callback?' + urlParams.toString(), {
                                    method: 'GET',
                                    credentials: 'same-origin',
                                    headers: {
                                        'Accept': 'application/json'
                                    }
                                })
                                .then(response => {
                                    if (response.ok) {
                                        // Redirect to success page
                                        window.location.href = '/dashboard';
                                    } else {
                                        // Redirect to error page
                                        return response.text().then(text => {
                                            window.location.href = '/identity/oauth/error?message=' + encodeURIComponent(text);
                                        });
                                    }
                                })
                                .catch(error => {
                                    // Redirect to error page
                                    window.location.href = '/identity/oauth/error?message=' + encodeURIComponent(error.message);
                                });
                            } else {
                                // Missing parameters, redirect to error
                                window.location.href = '/identity/oauth/error?message=' + encodeURIComponent('Missing OAuth parameters');
                            }
                        })();
                        """
                    }

                    // Fallback message
                    noscript {
                        div {
                            p {
                                TranslatedString(
                                    dutch:
                                        "JavaScript is uitgeschakeld. Klik op de knop hieronder om door te gaan.",
                                    english:
                                        "JavaScript is disabled. Please click the button below to continue."
                                )
                            }
                            .css
                            .color(.orange600)
                            .padding(.medium)
                            .backgroundColor(.orange100)
                            .borderRadius(.rem(0.5))
                            .marginTop(.large)

                            form(
                                action: "/api/oauth/callback",
                                method: .get
                            ) {

                                hiddenInputs

                                button(type: .submit) {
                                    TranslatedString(
                                        dutch: "Doorgaan",
                                        english: "Continue"
                                    )
                                }
                                .class("btn btn-primary")
                                .css
                                .padding(vertical: .large, horizontal: .medium)
                                .backgroundColor(.blue)
                                .color(.white)
                                .borderRadius(.rem(0.5))
                                .border(.none)
                                .cursor(.pointer)
                                .hover { $0.backgroundColor(.blue.opacity(0.9)) }
                            }
                            .css
                            .marginTop(.medium)

                            // Script to populate form values
                            script {
                                """
                                const urlParams = new URLSearchParams(window.location.search);
                                document.getElementById('fallback-code').value = urlParams.get('code') || '';
                                document.getElementById('fallback-state').value = urlParams.get('state') || '';
                                """
                            }
                        }
                    }
                }
                .css
                .width(.percent(100))
                .maxWidth(.px(400))
                .margin(.auto)
                .padding(.extraLarge)
                .textAlign(.center)
            }
        }
    }
}

// Namespace
extension Identity.OAuth {
    public enum Callback {}
}
