import Foundation
import Records
import Dependencies

extension Identity.Deletion {
    @Table("identity_deletions")
    public struct Record: Codable, Equatable, Identifiable, Sendable {
        public typealias ID = Tagged<Self, UUID>
        
        public let id: Identity.Deletion.Record.ID
        public var identityId: Identity.ID
        public var requestedAt: Date = Date()
        public var reason: String?
        public var confirmedAt: Date?
        public var cancelledAt: Date?
        public var scheduledFor: Date
        
        public init(
            id: Identity.Deletion.Record.ID,
            identityId: Identity.ID,
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
    }
}

extension Identity.Deletion.Record.Draft {
    public init(
        id: Identity.Deletion.Record.ID? = nil,
        identityId: Identity.ID,
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

// MARK: - Query Helpers

extension Identity.Deletion.Record {
    // No change needed
    public static func findByIdentity(_ identityId: Identity.ID) -> Where<Identity.Deletion.Record> {
        Self.where { $0.identityId.eq(identityId) }
    }
    
    // Replace IS NULL with == nil
    public static var pending: Where<Identity.Deletion.Record> {
        Self.where { deletion in
            deletion.confirmedAt == nil &&
            deletion.cancelledAt == nil
        }
    }
    
    // Replace IS NOT NULL with != nil
    public static var confirmed: Where<Identity.Deletion.Record> {
        Self.where { deletion in
            deletion.confirmedAt != nil
        }
    }
    
    public static var cancelled: Where<Identity.Deletion.Record> {
        Self.where { deletion in
            deletion.cancelledAt != nil
        }
    }
    
    // Use != nil and == nil with .lte() for date comparison
    public static var readyForDeletion: Where<Identity.Deletion.Record> {
        Self.where { deletion in
            deletion.confirmedAt != nil &&
            deletion.cancelledAt == nil &&
            deletion.scheduledFor.lte(Date())
        }
    }
    
    // Use != nil and == nil with .gt() for date comparison
    public static var awaitingGracePeriod: Where<Identity.Deletion.Record> {
        Self.where { deletion in
            deletion.confirmedAt != nil &&
            deletion.cancelledAt == nil &&
            deletion.scheduledFor.gt(Date())
        }
    }
}


// MARK: - Status & Actions

extension Identity.Deletion.Record {
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
        return Int(Foundation.ceil(timeInterval / (24 * 3600)))
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

