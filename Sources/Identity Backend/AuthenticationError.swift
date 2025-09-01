//
//  AuthenticationError.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 30/01/2025.
//

import Foundation
import IdentitiesTypes

extension Identity.Backend {
    /// Errors that can occur during authentication operations.
    package enum AuthenticationError: Swift.Error, Sendable {
        case invalidCredentials
        case accountNotFound
        case accountLocked
        case tokenExpired
        case tokenInvalid
        case emailNotVerified
        case notAuthenticated
    }
    
    /// Errors that can occur during validation operations.
    package enum ValidationError: Swift.Error, Sendable {
        case invalidInput(String)
        case passwordTooWeak
        case emailInvalid
        case emailAlreadyInUse
        case invalidToken
    }
}
