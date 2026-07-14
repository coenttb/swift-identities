//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 19/08/2025.
//

import Foundation
import HTML

extension MaxWidth {
    public static let identityComponentDesktop: Self = .rem(22)
    public static let identityComponentMobile: Self = .rem(20)
}

// MARK: - Webpage spacing scale, lifted onto the box-model properties this module styles
//
// `swift-webpage/Sources/Webpage/Length.swift:17-23` vends the semantic spacing scale as
// statics on `W3C_CSS_Values.LengthPercentage` (.extraSmall … .extraLarge). The tokens are
// live — they are NOT heritage ghosts.
//
// But `Padding` / `MarginTop` / `MarginBottom` are CSS *property* enums
// (`swift-w3c-css/Sources/W3C CSS BoxModel/`), not lengths. They take a `LengthPercentage`
// only through `LengthPercentageConvertible`, so an unlabeled `.padding(.medium)` looks for
// `Padding.medium` and does not resolve — while the labeled overload
// `.padding(vertical: .medium, horizontal: .large)` (swift-css/Sources/CSS/Layout/Padding.swift)
// takes `LengthPercentage` directly and resolves fine. Right token, wrong receiver.
//
// These statics lift the scale onto each property type, exactly as the `MaxWidth` extension
// above already does for this module — `MaxWidth` conforms to the same
// `LengthPercentageConvertible`, so that live, compiling extension is the proof of shape.

extension Padding {
    public static let extraSmall: Self = .all(LengthPercentage.extraSmall)
    public static let small: Self = .all(LengthPercentage.small)
    public static let medium: Self = .all(LengthPercentage.medium)
    public static let large: Self = .all(LengthPercentage.large)
    public static let extraLarge: Self = .all(LengthPercentage.extraLarge)
}

extension MarginTop {
    public static let extraSmall: Self = .lengthPercentage(LengthPercentage.extraSmall)
    public static let small: Self = .lengthPercentage(LengthPercentage.small)
    public static let medium: Self = .lengthPercentage(LengthPercentage.medium)
    public static let large: Self = .lengthPercentage(LengthPercentage.large)
    public static let extraLarge: Self = .lengthPercentage(LengthPercentage.extraLarge)
}

extension MarginBottom {
    public static let extraSmall: Self = .lengthPercentage(LengthPercentage.extraSmall)
    public static let small: Self = .lengthPercentage(LengthPercentage.small)
    public static let medium: Self = .lengthPercentage(LengthPercentage.medium)
    public static let large: Self = .lengthPercentage(LengthPercentage.large)
    public static let extraLarge: Self = .lengthPercentage(LengthPercentage.extraLarge)
}
