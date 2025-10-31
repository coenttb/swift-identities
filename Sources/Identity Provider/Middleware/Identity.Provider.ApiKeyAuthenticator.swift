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
      await withDependencies {
        $0.request = request
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
