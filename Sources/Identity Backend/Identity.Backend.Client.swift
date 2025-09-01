//
//  Identity.Backend.Client.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Foundation
import IdentitiesTypes

extension Identity.Backend {
    /// Backend implementation of the Identity Client interface.
    ///
    /// This client provides direct database access and business logic for identity operations.
    /// It is used by Provider for API serving and will be used by Standalone for local identity.
    /// Consumer cannot use this client as it doesn't have database access.
    public typealias Client = Identity.Client
}