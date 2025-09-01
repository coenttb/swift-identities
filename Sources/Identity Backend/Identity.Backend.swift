//
//  Identity.Backend.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Foundation
import IdentitiesTypes

extension Identity {
    /// Backend operations for identity management.
    ///
    /// This namespace provides direct database access and business logic
    /// that can be used by Provider (for API serving) or Standalone (for local identity).
    /// Backend operations are not available to Consumer which must use HTTP calls.
    public enum Backend {}
}