//
//  Identity.OAuth.State.Record.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/09/2025.
//

import Dependencies
import Foundation
import IdentitiesTypes
import Records

extension Identity.OAuth.State {
  @Table("oauth_states")
  public struct Record: Sendable {
    public var state: String  // Primary key

    @Column("provider")
    public var provider: String

    @Column("redirect_uri")
    public var redirectURI: String

    @Column("identity_id")
    public var identityId: Identity.ID?  // For linking to existing account

    @Column("created_at")
    public var createdAt: Date

    @Column("expires_at")
    public var expiresAt: Date

    public init(
      state: String,
      provider: String,
      redirectURI: String,
      identityId: Identity.ID? = nil,
      createdAt: Date = Date(),
      expiresAt: Date = Date().addingTimeInterval(600)  // 10 minutes
    ) {
      self.state = state
      self.provider = provider
      self.redirectURI = redirectURI
      self.identityId = identityId
      self.createdAt = createdAt
      self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
      Date() > expiresAt
    }
  }
}

// MARK: - Queries

extension Identity.OAuth.State.Record {
  /// Validate and retrieve state
  public static func validate(_ state: String) async throws -> Identity.OAuth.State.Record? {
    @Dependency(\.defaultDatabase) var db

    // First try to find the state
    guard
      let oauthState = try await db.read({ db in
        try await Self.all
          .where { $0.state.eq(state) }
          .fetchOne(db)
      })
    else {
      return nil
    }

    // Check if expired
    guard !oauthState.isExpired else {
      // Delete expired state
      try await db.write { db in
        try await Self.all
          .where { $0.state.eq(state) }
          .delete()
          .execute(db)
      }
      return nil
    }

    // Delete the state (one-time use)
    try await db.write { db in
      try await Self.all
        .where { $0.state.eq(state) }
        .delete()
        .execute(db)
    }

    return oauthState
  }

  /// Clean up expired states
  public static func cleanupExpired() async throws {
    @Dependency(\.defaultDatabase) var db

    try await db.write { db in
      try await Self.all
        .where { $0.expiresAt.lt(Date()) }
        .delete()
        .execute(db)
    }
  }

  /// Generate secure random state
  public static func generateState() -> String {
    let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
    return Data(bytes).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
