import Dependencies
import EmailAddress
import IdentitiesTypes
import Identity_Shared
import JWT
import ServerFoundationVapor
import Throttling

// NOTE: Identity.Consumer.Client.live is deprecated.
// The aggregated client pattern has been replaced with domain-specific clients.
// Use the individual domain client .live implementations instead:
// - Identity.Creation.Client.live
// - Identity.Authentication.Client.live
// - Identity.Deletion.Client.live
// - Identity.Email.Client.live
// - Identity.Password.Client.live

//extension Identity.Consumer.Client {
//    public static func live(
//        makeRequest: @escaping @Sendable (_ route: Identity.API) throws -> URLRequest
//    ) -> Self {
//        @Dependency(URLRequest.Handler.Identity.self) var handleRequest
//
//        return .init(
//            authenticate: .live { try makeRequest(.authenticate($0)) },
//            logout: .init(
//                current: {
//                    @Dependency(\.request) var request
//                    guard let request else { throw Abort.requestUnavailable }
//                    request.auth.logout(Identity.Token.Access.self)
//                },
//                all: {
//                    try await handleRequest(
//                        for: makeRequest(.logout(.all)),
//                        decodingTo: Bool.self
//                    )
//                }
//            ),
//            reauthorize: { password in
//                try await handleRequest(
//                    for: makeRequest(.reauthorize(.init(password: password))),
//                    decodingTo: Identity.Token.self
//                )
//            },
//            create: .live { try makeRequest(.create($0)) },
//            delete: .live { try makeRequest(.delete($0)) },
//            email: .live { try makeRequest(.email($0)) },
//            password: .live { try makeRequest(.password($0)) }
//        )
//    }
//}
