//
//  Identity.Standalone.View.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 29/01/2025.
//

import Foundation
import IdentitiesTypes

extension Identity.Standalone {
    /// View routing and navigation states for the standalone identity interface.
    ///
    /// This typealias maps to the shared Identity.View, allowing Standalone to use
    /// the same view routing as Consumer while having direct database access like Provider.
    public typealias View = Identity.View
}