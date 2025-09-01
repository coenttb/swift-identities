//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2024.
//

import ServerFoundationVapor
import IdentitiesTypes

extension Identity.View.HTMLDocument: AsyncResponseEncodable {
    public func encodeResponse(for request: Vapor.Request) async throws -> Vapor.Response {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html")
        let bytes: ContiguousArray<UInt8> = self.render()
        let string: String = String(decoding: bytes, as: UTF8.self)
        return .init(status: .ok, headers: headers, body: .init(string: string))
    }
}
