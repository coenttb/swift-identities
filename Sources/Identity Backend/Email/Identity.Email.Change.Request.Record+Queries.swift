import Dependencies
import EmailAddress
import Foundation
import Records

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

  package static func findByIdentity(_ identityId: Identity.ID) -> Where<
    Identity.Email.Change.Request.Record
  > {
    Self.where { $0.identityId.eq(identityId) }
  }

  package static func findByNewEmail(_ email: EmailAddress) -> Where<
    Identity.Email.Change.Request.Record
  > {
    Self.where { $0.newEmail.eq(email) }
  }

  package static var pending: Where<Identity.Email.Change.Request.Record> {
    Self.where { request in
      request.confirmedAt == nil && request.cancelledAt == nil && request.expiresAt > Date()
    }
  }

  package static var confirmed: Where<Identity.Email.Change.Request.Record> {
    Self.where { request in
      request.confirmedAt != nil
    }
  }

  package static var cancelled: Where<Identity.Email.Change.Request.Record> {
    Self.where { request in
      request.cancelledAt != nil
    }
  }

  package static var expired: Where<Identity.Email.Change.Request.Record> {
    Self.where { request in
      request.confirmedAt == nil && request.cancelledAt == nil && request.expiresAt <= Date()
    }
  }

  package static var valid: Where<Identity.Email.Change.Request.Record> {
    Self.where { request in
      request.confirmedAt == nil && request.cancelledAt == nil && request.expiresAt > Date()
    }
  }
}
