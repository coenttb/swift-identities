import Dependencies
import Foundation
import Identity_Shared
import JWT
import Throttling
@preconcurrency import Vapor

extension Identity.Provider {
    public struct ApiKeyAuthenticator: AsyncBearerAuthenticator {

        public init() {

        }

        public func authenticate(
            bearer: BearerAuthorization,
            for request: Request
        ) async throws {
            // swiftlint:disable:previous typed_throws_required
            await withDependencies {
                $0.vapor.request = request
            } operation: {
                @Dependency(\.identity) var identity
                do {
                    _ = try await identity.authenticate.client.apiKey(bearer.token)
                } catch {

                }
            }
        }
    }
}
