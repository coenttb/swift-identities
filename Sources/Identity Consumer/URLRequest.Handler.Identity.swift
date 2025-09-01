//
//  File 2.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 16/08/2025.
//

import Foundation
import ServerFoundation

extension URLRequest.Handler {
    package enum Identity {}
}

extension URLRequest.Handler.Identity: DependencyKey {
    package static var liveValue: URLRequest.Handler {
        .init(debug: false)
    }
    
    package static var testValue: URLRequest.Handler {
        .init(debug: true)
    }
}
