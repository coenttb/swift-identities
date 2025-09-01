//
//  Identity.Consumer.View.swift
//  swift-web
//
//  Created by Coen ten Thije Boonkkamp on 07/10/2024.
//

import CasePaths
import IdentitiesTypes
import ServerFoundation

extension Identity.Consumer {
    /// View routing and navigation states for the identity consumer interface.
    ///
    /// This namespace defines the possible view states and navigation flows for client-side
    /// identity management, including:
    /// - Authentication (login/logout)
    /// - Account creation and verification
    /// - Profile management (email, password)
    /// - Account deletion
    public typealias View = Identity.View
}
