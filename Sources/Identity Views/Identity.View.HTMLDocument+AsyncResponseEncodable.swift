//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2024.
//

import IdentitiesTypes
import ServerFoundationVapor

extension Identity.View.HTMLDocument: AsyncResponseEncodable {
  public func encodeResponse(
    for request: Vapor.Request
  ) async throws -> Vapor.Response {
    var headers = HTTPHeaders()
    headers.add(name: .contentType, value: "text/html")
    return .init(status: .ok, headers: headers, body: .init(data: .init(self.render())))
  }
}
