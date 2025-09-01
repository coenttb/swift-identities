//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 22/08/2025.
//

import Foundation
import HTML

extension PageModule.Theme {
    public static var authenticationFlow: Self {
        Self(
            topMargin: .rem(5),
            topMarginDesktop: .rem(18),
            bottomMargin: .rem(4),
            leftRightMargin: .rem(2),
            leftRightMarginDesktop: .rem(3),
            itemAlignment: .center
        )
    }
}

extension PageModule.Theme {
    public static var mfaSetup: Self {
        Self(
            topMargin: .rem(3),
            bottomMargin: .rem(4),
            leftRightMargin: .rem(2),
            leftRightMarginDesktop: .rem(3),
            itemAlignment: .center
        )
    }
}
