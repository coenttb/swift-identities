//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2024.
//

import HTML
import IdentitiesTypes
import Server_Vapor
import Vapor

extension Identity.View.HTMLDocument: AsyncResponseEncodable {
    public func encodeResponse(
        for request: Vapor.Request
    ) async throws -> Vapor.Response {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html")
        // The protocol-era `render()` is retired. `HTML.Document.Protocol` vends the document-shaped
        // render (doctype/html/head/body + two-phase style collection) through `asyncDocumentBytes()`
        // — swift-html-render/Sources/HTML Rendering Core/HTML.Document.Protocol.swift:156-161.
        let bytes = await self.asyncDocumentBytes()
        return .init(status: .ok, headers: headers, body: .init(data: .init(bytes)))
    }
}
