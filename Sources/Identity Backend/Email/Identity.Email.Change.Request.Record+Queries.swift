import Foundation
import Records
import Dependencies
import EmailAddress

// MARK: - Database Operations

extension Identity.Email.Change.Request.Record {
    
    // REMOVED: Async init that auto-saves to database
    // Create email change requests inline within transactions for proper atomicity
    
    // REMOVED: findByToken2 - Use direct queries at call site
}

// MARK: - Query Helpers

extension Identity.Email.Change.Request.Record {
    package static func findByToken(_ token: String) -> Where<Identity.Email.Change.Request.Record> {
        Self.where { $0.verificationToken.eq(token) }
    }
    
    package static func findByIdentity(_ identityId: Identity.ID) -> Where<Identity.Email.Change.Request.Record> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    package static func findByNewEmail(_ email: String) -> Where<Identity.Email.Change.Request.Record> {
        Self.where { $0.newEmail.eq(email) }
    }
    
    package static func findByNewEmail(_ email: EmailAddress) -> Where<Identity.Email.Change.Request.Record> {
        Self.where { $0.newEmail.eq(email.rawValue) }
    }
    
    package static var pending: Where<Identity.Email.Change.Request.Record> {
        Self.where { request in
            #sql("\(request.confirmedAt) IS NULL") &&
            #sql("\(request.cancelledAt) IS NULL") &&
            #sql("\(request.expiresAt) > CURRENT_TIMESTAMP")
        }
    }
    
    package static var confirmed: Where<Identity.Email.Change.Request.Record> {
        Self.where { request in
            #sql("\(request.confirmedAt) IS NOT NULL")
        }
    }
    
    package static var cancelled: Where<Identity.Email.Change.Request.Record> {
        Self.where { request in
            #sql("\(request.cancelledAt) IS NOT NULL")
        }
    }
    
    package static var expired: Where<Identity.Email.Change.Request.Record> {
        Self.where { request in
            #sql("\(request.confirmedAt) IS NULL") &&
            #sql("\(request.cancelledAt) IS NULL") &&
            #sql("\(request.expiresAt) <= CURRENT_TIMESTAMP")
        }
    }
    
    package static var valid: Where<Identity.Email.Change.Request.Record> {
        Self.where { request in
            #sql("\(request.confirmedAt) IS NULL") &&
            #sql("\(request.cancelledAt) IS NULL") &&
            #sql("\(request.expiresAt) > CURRENT_TIMESTAMP")
        }
    }
}
