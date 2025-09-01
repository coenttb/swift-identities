//
//  Identity+JWT.swift
//  coenttb-identities
//
//  JWT token generation helpers for the new Identity model
//

import Identity_Shared
import ServerFoundationVapor
import Dependencies
import Foundation
import JWT

extension Identity.Authentication.Response {
    /**
     * Creates an authentication response with access and refresh tokens
     * for the given identity
     */
    package init(_ identity: Database.Identity) async throws {
        @Dependency(\.tokenClient) var tokenClient
        
        let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
            identity.id,
            identity.email,
            identity.sessionVersion
        )
        
        self = .init(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}

extension Identity.Token.Access {
    /**
     * Creates an access token from an Identity
     *
     * IMPORTANT: The subject claim will contain both the identity ID and email
     * in the format "ID:email" to ensure both pieces of information are preserved.
     */
    package init(identity: Database.Identity) async throws {
        @Dependency(\.tokenClient) var tokenClient
        
        let tokenString = try await tokenClient.generateAccess(
            identity.id,
            identity.email,
            identity.sessionVersion
        )
        
        // Parse the generated token to create this instance
        let jwt = try JWT.parse(from: tokenString)
        try self.init(jwt: jwt)
    }
}

extension Identity.Token.Refresh {
    /**
     * Creates a refresh token from an Identity
     */
    package init(identity: Database.Identity) async throws {
        @Dependency(\.tokenClient) var tokenClient
        
        let tokenString = try await tokenClient.generateRefresh(
            identity.id,
            identity.sessionVersion
        )
        
        // Parse the generated token to create this instance
        let jwt = try JWT.parse(from: tokenString)
        try self.init(jwt: jwt)
    }
}

extension Identity.Token.Reauthorization {
    /**
     * Creates a reauthorization token from an Identity
     *
     * IMPORTANT: This now uses the same "ID:email" format for subject
     * to be consistent with access tokens.
     */
    package init(
        identity: Database.Identity,
        purpose: String = "general",
        allowedOperations: [String] = []
    ) async throws {
        @Dependency(\.tokenClient) var tokenClient
        
        let tokenString = try await tokenClient.generateReauthorization(
            identity.id,
            identity.sessionVersion,
            purpose,
            allowedOperations
        )
        
        // Parse the generated token to create this instance
        let jwt = try JWT.parse(from: tokenString)
        try self.init(jwt: jwt)
    }
}
