//
//  Identity.API.Profile.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import ServerFoundationVapor
import IdentitiesTypes
import Identity_Backend
import Dependencies
import Vapor

extension Identity.API.Profile {
    /// Handles profile API requests for standalone deployments.
    public static func response(
        _ profile: Identity.API.Profile
    ) async throws -> any AsyncResponseEncodable {
        
        // Get authenticated identity
        let identity = try await Database.Identity.get(by: .auth)
        
        switch profile {
        case .get:
            // Get or create profile
            let profile = try await Database.Identity.Profile.getOrCreate(for: identity.id)
            
            let profileResponse = Response(
                id: profile.id,
                identityId: profile.identityId,
                displayName: profile.displayName,
                email: identity.email,
                createdAt: profile.createdAt,
                updatedAt: profile.updatedAt
            )
            
            return Vapor.Response.success(true, data: profileResponse)
            
        case .updateDisplayName(let request):
            @Dependency(\.request) var vaporRequest
            @Dependency(\.tokenClient) var tokenClient
            
            // Get or create profile
            var profile = try await Database.Identity.Profile.getOrCreate(for: identity.id)
            
            // Update display name
            try await profile.updateDisplayName(request.displayName)
            
            // Generate new tokens with updated displayName
            let (newAccessToken, newRefreshToken) = try await tokenClient.generateTokenPair(
                identity.id,
                identity.email,
                identity.sessionVersion
            )
            
            // Check if this is a form submission (browser request)
            let isFormSubmission = vaporRequest?.headers["accept"].contains { 
                $0.contains("text/html") 
            } ?? false
            
            if isFormSubmission {
                // Browser request - update cookies with new tokens and redirect
                let response = Vapor.Response(
                    status: .seeOther,
                    headers: ["Location": "/profile/edit?success=displayName"]
                )
                
                response.expire(cookies: .identity)
                
                return response
                    .withTokens(for: .init(accessToken: newAccessToken, refreshToken: newRefreshToken))
            } else {
                // API request - return JSON with new tokens
                return Vapor.Response.success(true, data: [
                    "displayName": request.displayName,
                    "accessToken": newAccessToken,
                    "refreshToken": newRefreshToken
                ])
            }
        }
    }
}
