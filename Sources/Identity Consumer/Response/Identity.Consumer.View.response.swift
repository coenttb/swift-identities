//
//  Identity.Consumer.View.response.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import ServerFoundationVapor
import IdentitiesTypes
import Identity_Frontend
import Dependencies
import Vapor

extension Identity.View {
    /// Handles view requests for Consumer deployments.
    /// Dispatches to appropriate Frontend handlers.
    public static func consumerResponse(
        view: Identity.View
    ) async throws -> any AsyncResponseEncodable {
        
        @Dependency(\.identity.consumer) var configuration
        
        // Check authentication requirements
        try await Identity.Frontend.protect(
            view: view,
            router: configuration.router
        )
        
        // Dispatch to appropriate handler
        switch view {
        case .create(let create):
            switch create {
            case .request:
                return try await Identity.Frontend.handleCreateRequest(configuration: configuration)
            case .verify:
                return try await Identity.Frontend.handleCreateVerify(configuration: configuration)
            }
            
        case .authenticate(let authenticate):
            switch authenticate {
            case .credentials:
                return try await Identity.Frontend.handleAuthenticateCredentials(configuration: configuration)
            }
            
        case .logout:
            return try await Identity.Logout.response(
                client: configuration.client,
                redirect: configuration.redirect
            )
            
        case .delete:
            return try await Identity.Frontend.handleDeleteRequest(configuration: configuration)
            
        case .email(let email):
            switch email {
            case .change(let change):
                switch change {
                case .request:
                    return try await Identity.Frontend.handleEmailChangeRequest(configuration: configuration)
                case .confirm:
                    return try await Identity.Frontend.handleEmailChangeConfirm(configuration: configuration)
                case .reauthorization:
                    return try await Identity.Frontend.handleEmailChangeReauthorization(configuration: configuration)
                }
            }
            
        case .password(let password):
            switch password {
            case .reset(let reset):
                switch reset {
                case .request:
                    return try await Identity.Frontend.handlePasswordResetRequest(configuration: configuration)
                case .confirm:
                    return try await Identity.Frontend.handlePasswordResetConfirm(configuration: configuration)
                }
            case .change(let change):
                switch change {
                case .request:
                    return try await Identity.Frontend.handlePasswordChangeRequest(configuration: configuration)
                }
            }
            
        case .mfa(let mfa):
            switch mfa {
            case .verify(let challenge):
                return try await Identity.Frontend.handleMFAVerify(
                    challenge: challenge,
                    configuration: configuration
                )
            case .backupCodes(let backupCodes):
                switch backupCodes {
                case .verify(let challenge):
                    return try await Identity.Frontend.handleMFABackupCodeVerify(
                        challenge: challenge,
                        configuration: configuration
                    )
                default:
                    // Other backup code views require backend access
                    return try await Identity.Frontend.handleMFABackendRequired(
                        mfa: mfa,
                        configuration: configuration
                    )
                }
            default:
                // Other MFA views require backend access
                return try await Identity.Frontend.handleMFABackendRequired(
                    mfa: mfa,
                    configuration: configuration
                )
            }
        }
    }
}
