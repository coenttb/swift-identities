//
//  File.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 11/09/2025.
//

import ServerFoundation

extension Identity.Authentication.Response {
  /**
     * Creates an authentication response with access and refresh tokens
     * for the given identity
     */
  package init(_ identity: Identity.Record) async throws {
    @Dependency(\.tokenClient) var tokenClient

    let (accessToken, refreshToken) = try await tokenClient.generateTokenPair(
      identity.id,
      identity.email,
      identity.sessionVersion
    )

    self = .init(
      accessToken: accessToken,
      refreshToken: refreshToken
    )
  }
}
