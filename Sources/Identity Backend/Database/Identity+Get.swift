//
//  Identity+Get.swift
//  coenttb-identities
//
//  Created on migration from Fluent to StructuredQueriesPostgres
//

import Foundation
import Dependencies
import EmailAddress
import IdentitiesTypes
import Vapor
import ServerFoundationVapor

extension Database.Identity {
    public enum Get {
        public enum Identifier {
            case id(UUID)
            case email(String)
            case auth
            
            public static func email(_ email: EmailAddress) -> Self {
                .email(email.rawValue)
            }
        }
    }
    
    public static func get(
        by identifier: Database.Identity.Get.Identifier
    ) async throws -> Database.Identity {
        switch identifier {
        case .id(let id):
            guard let identity = try await Database.Identity.findById(id) else {
                throw Abort(.notFound, reason: "Identity not found for id \(id)")
            }
            return identity
            
        case .email(let email):
            guard let identity = try await Database.Identity.findByEmail(email) else {
                throw Abort(.notFound, reason: "Identity not found for email \(email)")
            }
            return identity
            
        case .auth:
            @Dependency(\.request) var request
            @Dependency(\.logger) var logger
            guard let request else {
                logger.error("Request not available for Identity.get(.auth)", metadata: [
                    "component": "Database.Identity",
                    "operation": "get.auth"
                ])
                throw Abort.requestUnavailable
            }
            
            // First check for Identity.Token.Access (used by Standalone/Consumer)
            if let accessToken = request.auth.get(Identity.Token.Access.self) {
                return try await Database.Identity.get(by: .id(accessToken.identityId))
            }
            
            // Fall back to checking for Database.Identity (used by Provider)
            if let authIdentity = request.auth.get(Database.Identity.self) {
                // Refresh from database to ensure we have latest data
                return try await Database.Identity.get(by: .id(authIdentity.id))
            }
            
            // No authentication found
            throw Abort(.unauthorized, reason: "Not authenticated")
        }
    }
}

// MARK: - Password Verification

extension Database.Identity {
    package init(
        id: UUID,
        email: EmailAddress,
        password: String,
        emailVerificationStatus: Database.Identity.EmailVerificationStatus = .unverified
    ) throws {
        self.init(
            id: id,
            email: email,
            passwordHash: try Bcrypt.hash(password),
            emailVerificationStatus: emailVerificationStatus
        )
    }
}

// MARK: - Dependency (REMOVED)
// The identityQueries dependency has been deprecated.
// Use static methods on the models directly instead.
