import Foundation
import Records
import Dependencies

extension Database.Identity {
    @Table("identity_deletions")
    public struct Deletion: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public var identityId: UUID
        public var requestedAt: Date = Date()
        public var reason: String?
        public var confirmedAt: Date?
        public var cancelledAt: Date?
        public var scheduledFor: Date
        
        public init(
            id: UUID,
            identityId: UUID,
            requestedAt: Date = Date(),
            reason: String? = nil,
            confirmedAt: Date? = nil,
            cancelledAt: Date? = nil,
            scheduledFor: Date
        ) {
            self.id = id
            self.identityId = identityId
            self.requestedAt = requestedAt
            self.reason = reason
            self.confirmedAt = confirmedAt
            self.cancelledAt = cancelledAt
            self.scheduledFor = scheduledFor
        }
        
        public init(
            id: UUID,
            identityId: UUID,
            reason: String? = nil,
            gracePeriodDays: Int = 30
        ) {
            @Dependency(\.date) var date
            
            self.id = id
            self.identityId = identityId
            self.requestedAt = date()
            self.reason = reason
            self.confirmedAt = nil
            self.cancelledAt = nil
            self.scheduledFor = date().addingTimeInterval(TimeInterval(gracePeriodDays * 24 * 3600))
        }
    }
}

// MARK: - Query Helpers

extension Database.Identity.Deletion {
    public static func findByIdentity(_ identityId: UUID) -> Where<Database.Identity.Deletion> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    public static var pending: Where<Database.Identity.Deletion> {
        Self.where { deletion in
            #sql("\(deletion.confirmedAt) IS NULL") &&
            #sql("\(deletion.cancelledAt) IS NULL")
        }
    }
    
    public static var confirmed: Where<Database.Identity.Deletion> {
        Self.where { deletion in
            #sql("\(deletion.confirmedAt) IS NOT NULL")
        }
    }
    
    public static var cancelled: Where<Database.Identity.Deletion> {
        Self.where { deletion in
            #sql("\(deletion.cancelledAt) IS NOT NULL")
        }
    }
    
    public static var readyForDeletion: Where<Database.Identity.Deletion> {
        Self.where { deletion in
            #sql("\(deletion.confirmedAt) IS NOT NULL") &&
            #sql("\(deletion.cancelledAt) IS NULL") &&
            #sql("\(deletion.scheduledFor) <= CURRENT_TIMESTAMP")
        }
    }
    
    public static var awaitingGracePeriod: Where<Database.Identity.Deletion> {
        Self.where { deletion in
            #sql("\(deletion.confirmedAt) IS NOT NULL") &&
            #sql("\(deletion.cancelledAt) IS NULL") &&
            #sql("\(deletion.scheduledFor) > CURRENT_TIMESTAMP")
        }
    }
}

// MARK: - Status & Actions

extension Database.Identity.Deletion {
    public enum Status: String, Codable, Sendable {
        case pending
        case confirmed
        case cancelled
        case readyForDeletion
        case awaitingGracePeriod
    }
    
    public var status: Status {
        @Dependency(\.date) var date
        
        if cancelledAt != nil {
            return .cancelled
        }
        
        if confirmedAt != nil {
            if scheduledFor <= date() {
                return .readyForDeletion
            } else {
                return .awaitingGracePeriod
            }
        }
        
        return .pending
    }
    
    public var isPending: Bool {
        confirmedAt == nil && cancelledAt == nil
    }
    
    public var isConfirmed: Bool {
        confirmedAt != nil && cancelledAt == nil
    }
    
    public var isCancelled: Bool {
        cancelledAt != nil
    }
    
    public var isReadyForDeletion: Bool {
        @Dependency(\.date) var date
        return isConfirmed && scheduledFor <= date()
    }
    
    public var daysUntilDeletion: Int? {
        guard isConfirmed else { return nil }
        @Dependency(\.date) var date
        let timeInterval = scheduledFor.timeIntervalSince(date())
        guard timeInterval > 0 else { return 0 }
        return Int(ceil(timeInterval / (24 * 3600)))
    }
    
    public mutating func confirm() {
        @Dependency(\.date) var date
        self.confirmedAt = date()
    }
    
    public mutating func cancel() {
        @Dependency(\.date) var date
        self.cancelledAt = date()
    }
    
    public mutating func reschedule(daysFromNow: Int) {
        @Dependency(\.date) var date
        self.scheduledFor = date().addingTimeInterval(TimeInterval(daysFromNow * 24 * 3600))
    }
}
