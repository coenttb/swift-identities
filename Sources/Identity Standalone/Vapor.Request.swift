//
//  File.swift
//  swift-identities
//
//  Created by Coen ten Thije Boonkkamp on 25/08/2025.
//

import Identity_Frontend
import Vapor

extension Vapor.Request {
  public func redirect(to view: Identity.View) -> Response {
    @Dependency(\.identity.router) var router
    return self.redirect(to: router.url(for: .view(view)).absoluteString)
  }
}
