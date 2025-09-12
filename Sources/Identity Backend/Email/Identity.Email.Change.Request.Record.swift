import Foundation
import Records
import Dependencies
import EmailAddress
import Crypto

extension Identity.Email.Change.Request {
    @Table("identity_email_change_requests")
    package struct Record: Codable, Equatable, Identifiable, Sendable {
        package let id: UUID
        package var identityId: Identity.ID
        internal var newEmail: String
        package var verificationToken: String
        package var requestedAt: Date = Date()
        package var expiresAt: Date
        package var confirmedAt: Date?
        package var cancelledAt: Date?
        
        package var newEmailAddress: EmailAddress {
            get {
                try! EmailAddress(newEmail)
            }
            set {
                newEmail = newValue.rawValue
            }
        }
        
        package init(
            id: UUID,
            identityId: Identity.ID,
            newEmail: String,
            verificationToken: String,
            requestedAt: Date = Date(),
            expiresAt: Date,
            confirmedAt: Date? = nil,
            cancelledAt: Date? = nil
        ) {
            self.id = id
            self.identityId = identityId
            self.newEmail = newEmail
            self.verificationToken = verificationToken
            self.requestedAt = requestedAt
            self.expiresAt = expiresAt
            self.confirmedAt = confirmedAt
            self.cancelledAt = cancelledAt
        }
        
        package init(
            id: UUID,
            identityId: Identity.ID,
            newEmail: EmailAddress,
            expirationHours: Int = 24
        ) {
            @Dependency(\.date) var date
            
            self.id = id
            self.identityId = identityId
            self.newEmail = newEmail.rawValue
            self.verificationToken = Self.generateVerificationToken()
            self.requestedAt = date()
            self.expiresAt = date().addingTimeInterval(TimeInterval(expirationHours * 3600))
            self.confirmedAt = nil
            self.cancelledAt = nil
        }
        
        private static func generateVerificationToken() -> String {
            SymmetricKey(size: .bits256)
                .withUnsafeBytes { Data($0) }
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
    }
}



// MARK: - Status & Actions

extension Identity.Email.Change.Request.Record {
    package enum Status: String, Codable, Sendable {
        case pending
        case confirmed
        case cancelled
        case expired
    }
    
    package var status: Status {
        @Dependency(\.date) var date
        
        if confirmedAt != nil {
            return .confirmed
        }
        
        if cancelledAt != nil {
            return .cancelled
        }
        
        if expiresAt <= date() {
            return .expired
        }
        
        return .pending
    }
    
    package var isPending: Bool {
        status == .pending
    }
    
    package var isConfirmed: Bool {
        confirmedAt != nil
    }
    
    package var isCancelled: Bool {
        cancelledAt != nil
    }
    
    package var isExpired: Bool {
        @Dependency(\.date) var date
        return confirmedAt == nil && cancelledAt == nil && expiresAt <= date()
    }
    
    package var isValid: Bool {
        @Dependency(\.date) var date
        return confirmedAt == nil && cancelledAt == nil && expiresAt > date()
    }
    
    package var hoursUntilExpiration: Int? {
        guard isValid else { return nil }
        @Dependency(\.date) var date
        let timeInterval = expiresAt.timeIntervalSince(date())
        guard timeInterval > 0 else { return 0 }
        return Int(ceil(timeInterval / 3600))
    }
    
    package mutating func confirm() {
        @Dependency(\.date) var date
        self.confirmedAt = date()
    }
    
    package mutating func cancel() {
        @Dependency(\.date) var date
        self.cancelledAt = date()
    }
    
    package mutating func extendExpiration(hours: Int) {
        @Dependency(\.date) var date
        self.expiresAt = date().addingTimeInterval(TimeInterval(hours * 3600))
    }
}

extension Identity.Email.Change.Request.Record {
    
    /// Find email change request by token with identity data
    /// Replaces: findByToken + separate identity lookup
    package static func findByTokenWithIdentity(_ token: String) async throws -> EmailChangeRequestWithIdentity? {
        @Dependency(\.defaultDatabase) var db
        
        return try await db.read { db in
            try await Identity.Email.Change.Request.Record
                .join(Identity.Token.Record.all) { request, tokenEntity in
                    request.identityId.eq(tokenEntity.identityId)
                        .and(tokenEntity.value.eq(token))
                        .and(tokenEntity.type.eq(Identity.Token.Record.TokenType.emailChange))
                        .and(tokenEntity.validUntil > Date())
                }
                .join(Identity.Record.all) { request, _, identity in
                    request.identityId.eq(identity.id)
                }
                .select { request, _, identity in
                    EmailChangeRequestWithIdentity.Columns(
                        emailChangeRequest: request,
                        identity: identity,
                        currentEmail: identity.emailString
                    )
                }
                .fetchOne(db)
        }
    }
}

@Selection
package struct EmailChangeRequestWithIdentity: Sendable {
    package let emailChangeRequest: Identity.Email.Change.Request.Record
    package let identity: Identity.Record
    package let currentEmail: String
}

@Selection
package struct EmailChangeValidationData: Sendable {
    package let token: Identity.Token.Record
    package let request: Identity.Email.Change.Request.Record
    package let identity: Identity.Record
}
