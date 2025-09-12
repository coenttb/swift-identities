# RepoTraffic OAuth Setup Guide

This guide demonstrates how RepoTraffic configures OAuth with token storage for GitHub API access.

## Environment Variables

Create a `.env` file with the following variables:

```bash
# OAuth Encryption Key (required for token storage)
# Generate with: openssl rand -base64 32
IDENTITIES_ENCRYPTION_KEY=your-base64-encoded-32-byte-key-here

# GitHub OAuth App Credentials
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret

# Other Identity settings
IDENTITIES_ISSUER=https://repotraffic.com
IDENTITIES_JWT_ACCESS_EXPIRY=900
IDENTITIES_JWT_REFRESH_EXPIRY=2592000
```

## RepoTraffic Configuration

In your RepoTraffic server configuration:

```swift
import IdentitiesGitHub
import Identity_Backend

// Configure GitHub provider with API access enabled
let githubProvider = GitHubOAuthProvider(
    clientId: Environment.get("GITHUB_CLIENT_ID"),
    clientSecret: Environment.get("GITHUB_CLIENT_SECRET"),
    scopes: ["repo", "read:org"],  // Scopes needed for traffic data
    requiresAPIAccess: true  // CRITICAL: Enables encrypted token storage
)

// Set up OAuth provider registry
let oauthRegistry = Identity.OAuth.ProviderRegistry()
await oauthRegistry.register(githubProvider)

// Configure Identity Backend Client
let identityClient = Identity.Backend.Client.live(
    sendVerificationEmail: { /* ... */ },
    sendPasswordResetEmail: { /* ... */ },
    // ... other email handlers
    oauthProviderRegistry: oauthRegistry  // Pass the registry
)
```

## Using OAuth in RepoTraffic

### 1. User Authentication Flow

```swift
// User clicks "Sign in with GitHub"
let authURL = try await identityClient.oauth.authorizationURL(
    "github",
    redirectURI: "https://repotraffic.com/oauth/callback"
)
// Redirect user to authURL
```

### 2. OAuth Callback Handler

```swift
// Handle callback from GitHub
let response = try await identityClient.oauth.callback(
    Identity.OAuth.Credentials(
        code: request.query["code"],
        state: request.query["state"],
        provider: "github",
        redirectURI: "https://repotraffic.com/oauth/callback"
    )
)
// User is now authenticated
```

### 3. Background Job for Fetching Traffic Data

```swift
struct FetchTrafficJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        @Dependency(\.identityClient) var identity
        @Dependency(\.githubClient) var github
        
        for user in users {
            // Get valid GitHub token (handles refresh automatically)
            guard let token = try await identity.oauth.getValidToken("github") else {
                logger.warning("No GitHub token for user \(user.id)")
                continue
            }
            
            // Use token to fetch repository traffic
            for repo in user.trackedRepositories {
                let traffic = try await github.getTrafficData(
                    owner: repo.owner,
                    name: repo.name,
                    token: token  // Decrypted and ready to use
                )
                
                // Store traffic data
                try await saveTrafficData(traffic, for: repo)
            }
        }
    }
}
```

## How It Works

1. **Token Storage Decision**: 
   - When `requiresAPIAccess: true` is set, tokens are encrypted and stored
   - When `false` (default), tokens are used for authentication only

2. **Encryption**:
   - Uses AES-GCM encryption with the key from `IDENTITIES_ENCRYPTION_KEY`
   - Tokens are prefixed with "v1:" for version tracking
   - Falls back gracefully in development if no key is set

3. **Token Retrieval**:
   - `getValidToken("github")` decrypts and returns the access token
   - Automatically handles refresh if token is expired (though GitHub tokens don't expire)
   - Returns `nil` if no token is stored or provider doesn't store tokens

4. **Security**:
   - Tokens are never stored in plain text
   - Encryption key should be kept secure and rotated periodically
   - Each environment (dev, staging, prod) should have different keys

## Troubleshooting

### No Token Available
If `getValidToken` returns `nil`, check:
1. Provider has `requiresAPIAccess: true`
2. `IDENTITIES_ENCRYPTION_KEY` is set
3. User has authenticated with OAuth
4. OAuth connection exists in database

### Encryption Errors
If you see encryption errors:
1. Verify `IDENTITIES_ENCRYPTION_KEY` is base64-encoded 32 bytes
2. Check that the same key is used for encryption and decryption
3. Ensure the key hasn't changed since tokens were stored

### Development Mode
In development without encryption key:
- Tokens are stored unencrypted with warnings
- Set `IDENTITIES_ENCRYPTION_KEY` before production deployment
