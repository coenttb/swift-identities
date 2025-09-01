import Identity_Shared
import ServerFoundationVapor
import Dependencies
import EmailAddress
import IdentitiesTypes
import JWT
import Throttling

extension Identity.Consumer.Client {
    public static func live(
        makeRequest: @escaping @Sendable (_ route: Identity.Consumer.API) throws -> URLRequest
    ) -> Self {

        @Dependency(\.identity.consumer.client) var client
        @Dependency(URLRequest.Handler.Identity.self) var handleRequest
        
        return .init(
            authenticate: .live { try makeRequest(.authenticate($0)) },
            logout: .init(
                current: {
                    @Dependency(\.request) var request
                    guard let request else { throw Abort.requestUnavailable }
                    request.auth.logout(Identity.Token.Access.self)
                },
                all: {
                    try await handleRequest(
                        for: makeRequest(.logout(.all)),
                        decodingTo: Bool.self
                    )
                }
            ),
            reauthorize: { password in
                try await handleRequest(
                    for: makeRequest(.reauthorize(.init(password: password))),
                    decodingTo: Identity.Token.self
                )
            },
            create: .live { try makeRequest(.create($0)) },
            delete: .live { try makeRequest(.delete($0)) },
            email: .live { try makeRequest(.email($0)) },
            password: .live { try makeRequest(.password($0)) }
        )
    }
}

extension Identity.Consumer.Client {
    public enum Error: Swift.Error {
        case requestError
        case printError
    }
}
