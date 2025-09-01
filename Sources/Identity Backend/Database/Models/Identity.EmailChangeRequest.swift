import Foundation
import Records
import Dependencies
import EmailAddress
import Crypto

extension Database.Identity {
    package enum Email {
        package enum Change {
            
        }
    }
}

extension Database.Identity.Email.Change {
    @Table("identity_email_change_requests")
    package struct Request: Codable, Equatable, Identifiable, Sendable {
        package let id: UUID
        package var identityId: UUID
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
            identityId: UUID,
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
            identityId: UUID,
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

// MARK: - Query Helpers

extension Database.Identity.Email.Change.Request {
    package static func findByToken(_ token: String) -> Where<Database.Identity.Email.Change.Request> {
        Self.where { $0.verificationToken.eq(token) }
    }
    
    package static func findByIdentity(_ identityId: UUID) -> Where<Database.Identity.Email.Change.Request> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    package static func findByNewEmail(_ email: String) -> Where<Database.Identity.Email.Change.Request> {
        Self.where { $0.newEmail.eq(email) }
    }
    
    package static func findByNewEmail(_ email: EmailAddress) -> Where<Database.Identity.Email.Change.Request> {
        Self.where { $0.newEmail.eq(email.rawValue) }
    }
    
    package static var pending: Where<Database.Identity.Email.Change.Request> {
        Self.where { request in
            #sql("\(request.confirmedAt) IS NULL") &&
            #sql("\(request.cancelledAt) IS NULL") &&
            #sql("\(request.expiresAt) > CURRENT_TIMESTAMP")
        }
    }
    
    package static var confirmed: Where<Database.Identity.Email.Change.Request> {
        Self.where { request in
            #sql("\(request.confirmedAt) IS NOT NULL")
        }
    }
    
    package static var cancelled: Where<Database.Identity.Email.Change.Request> {
        Self.where { request in
            #sql("\(request.cancelledAt) IS NOT NULL")
        }
    }
    
    package static var expired: Where<Database.Identity.Email.Change.Request> {
        Self.where { request in
            #sql("\(request.confirmedAt) IS NULL") &&
            #sql("\(request.cancelledAt) IS NULL") &&
            #sql("\(request.expiresAt) <= CURRENT_TIMESTAMP")
        }
    }
    
    package static var valid: Where<Database.Identity.Email.Change.Request> {
        Self.where { request in
            #sql("\(request.confirmedAt) IS NULL") &&
            #sql("\(request.cancelledAt) IS NULL") &&
            #sql("\(request.expiresAt) > CURRENT_TIMESTAMP")
        }
    }
}

// MARK: - Status & Actions

extension Database.Identity.Email.Change.Request {
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
