import Identity_Shared
import Dependencies
import Foundation
import JWT
import Throttling
@preconcurrency import Vapor

extension Identity.Provider {
    public struct ApiKeyAuthenticator: AsyncBearerAuthenticator {

        public init(

        ) {

        }

        @Dependency(\.identity.provider.client) var identity

        public func authenticate(
            bearer: BearerAuthorization,
            for request: Request
        ) async throws {
            await withDependencies {
                $0.request = request
            } operation: {
                do {
                    try await withDependencies {
                        $0.request = request
                    } operation: {
                        _ = try await identity.authenticate.apiKey(bearer.token)
                    }
                } catch {

                }
            }
        }
    }
}
