//
//  Identity.OAuth.response.swift
//  coenttb-identities
//
//  OAuth view response handlers
//

import ServerFoundationVapor
import IdentitiesTypes
import HTML
import ServerFoundationVapor
import Identity_Views
import Dependencies
import Language

// MARK: - Response Dispatcher

extension Identity.OAuth {
    /// Dispatches OAuth view requests to appropriate handlers.
    public static func response(
        view: Identity.View.OAuth
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        @Dependency(\.identity.router) var router
        
        // Check if OAuth is configured
        guard configuration.identity.oauth != nil else {
            throw Abort(.notImplemented, reason: "OAuth is not configured")
        }
        
        switch view {
        case .login:
            return try await handleLogin()
            
        case .callback(let callbackRequest):
            return try await handleCallback(callbackRequest: callbackRequest)
            
        case .connections:
            return try await handleConnections()
            
        case .error(let message):
            return try await handleError(message: message)
        }
    }
}

// MARK: - View Handlers

extension Identity.OAuth {
    
    /// Handles OAuth login view showing available providers.
    private static func handleLogin(

    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        
        guard let oauth = configuration.identity.oauth else {
            throw Abort(.notImplemented, reason: "OAuth is not configured")
        }
        
        // Get available providers
        let providers = try await oauth.client.providers()
        
        // Generate authorization URLs for each provider
        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }
        
        let scheme = request.headers.first(name: "X-Forwarded-Proto") ?? "http"
        let host = request.headers.first(name: .host) ?? "localhost"
        let redirectURI = "\(scheme)://\(host)/identity/oauth/callback"
        
        var providerUrls: [(provider: Identity.OAuth.Provider, url: URL)] = []
        for provider in providers {
            let authURL = try await oauth.client.authorizationURL(
                provider.identifier,
                redirectURI
            )
            providerUrls.append((provider: provider, url: authURL))
        }
        
        return try await Identity.Frontend.htmlDocument(
            for: .oauth(.login),
            title: "Sign in with OAuth",
            description: "Sign in using your preferred OAuth provider"
        ) {
            Identity.OAuth.Login.View(
                providers: providerUrls,
                cancelHref: configuration.navigation.home
            )
        }
    }
    
    /// Handles OAuth callback processing.
    private static func handleCallback(
        callbackRequest: Identity.OAuth.CallbackRequest,

    ) async throws -> any AsyncResponseEncodable {
        // The callback is typically handled by the API endpoint
        // This view can show a processing state or error
        return try await Identity.Frontend.htmlDocument(
            for: .oauth(.callback(callbackRequest)),
            title: "Processing OAuth Login",
            description: "Processing your OAuth login"
        ) {
            @Dependency(Identity.Frontend.Configuration.self) var configuration
            
            Identity.OAuth.Callback.View(
                provider: callbackRequest.provider,
                redirectUrl: configuration.redirect.loginSuccess
            )
        }
    }
    
    /// Handles OAuth connections management view.
    private static func handleConnections(

    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Frontend.Configuration.self) var configuration
        
        guard let oauth = configuration.identity.oauth else {
            throw Abort(.notImplemented, reason: "OAuth is not configured")
        }
        
        // Get current connections
        let connections = try await oauth.client.getAllConnections()
        
        // Get available providers
        let allProviders = try await oauth.client.providers()
        
        // Determine which providers are connected
        let connectedProviders = Set(connections.map { $0.provider })
        let availableProviders = allProviders.filter { !connectedProviders.contains($0.identifier) }
        
        @Dependency(\.identity.router) var router
        
        return try await Identity.Frontend.htmlDocument(
            for: .oauth(.connections),
            title: "Manage OAuth Connections",
            description: "Manage your connected OAuth accounts"
        ) {
            return Identity.OAuth.Connections.View(
                connections: connections,
                availableProviders: availableProviders,
                connectAction: { provider in
                    router.url(for: .api(.oauth(.authorize(provider: provider))))
                },
                disconnectAction: { provider in
                    router.url(for: .api(.oauth(.disconnect(provider: provider))))
                },
                dashboardHref: configuration.navigation.home
            )
        }
    }
    
    /// Handles OAuth error view.
    private static func handleError(
        message: String,

    ) async throws -> any AsyncResponseEncodable {
        return try await Identity.Frontend.htmlDocument(
            for: .oauth(.error(message)),
            title: "OAuth Error",
            description: "An error occurred during OAuth authentication"
        ) {
            @Dependency(Identity.Frontend.Configuration.self) var configuration
            @Dependency(\.identity.router) var router
            
            return Identity.OAuth.Error.View(
                errorMessage: message,
                retryHref: router.url(for: .view(.oauth(.login))),
                cancelHref: configuration.navigation.home
            )
        }
    }
}
