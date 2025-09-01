//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 07/02/2025.
//

import ServerFoundationVapor

extension Identity.API {
    package static func protect<Authenticatable: Vapor.Authenticatable>(
        api: Identity.API,
        with type: Authenticatable.Type
    ) throws {

        switch api {
        case .authenticate(let authenticate):
            switch authenticate {
            case .credentials, .token, .apiKey:
                break
            }

        case .create:
            break
        case .delete:
            @Dependency(\.request) var request
            guard let request else { throw Abort.requestUnavailable }
            try request.auth.require(type)

        case .email:
            @Dependency(\.request) var request
            guard let request else { throw Abort.requestUnavailable }
            try request.auth.require(type)

        case .logout(.current):
            // Logout doesn't require authentication - we just clear cookies
            // If tokens are expired, we still want to clear them
            break
            
        case .logout(.all):
            // Logout all doesn't require authentication - we just clear cookies
            // If tokens are expired, we still want to clear them
            break

        case .reauthorize:
            @Dependency(\.request) var request
            guard let request else { throw Abort.requestUnavailable }
            try request.auth.require(type)

        case .password(let password):
            switch password {
            case .reset:
                break
            case .change:
                @Dependency(\.request) var request
                guard let request else { throw Abort.requestUnavailable }
                try request.auth.require(type)
            }
            
        case .mfa(let mfa):
            // MFA verify endpoint doesn't require authentication (uses session token)
            // All other MFA endpoints require authentication
            switch mfa {
            case .verify:
                // No authentication required - validates session token internally
                break
            default:
                // All other MFA endpoints require authentication
                @Dependency(\.request) var request
                guard let request else { throw Abort.requestUnavailable }
                try request.auth.require(type)
            }
        }
    }
}
