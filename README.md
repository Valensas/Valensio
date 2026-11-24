# Valensio

A lightweight, async/await HTTP client for Apple platforms, built on `URLSession`.

Valensio provides a small, composable API with a request pipeline, interceptors, pluggable body encoding and decoding, and first-class OpenID Connect (OIDC) support.

## Features

- **`HttpClient`** — An async `URLSession`-based client with request and response body encoding and decoding.
- **`UrlHttpClient`** — A convenience subclass that binds requests to a base URL and relative paths.
- **Interceptors** — A composable `HttpInterceptor` chain for cross-cutting concerns, including:
  - `BasicAuthInterceptor` — Adds HTTP Basic authentication.
  - `BearerTokenInterceptor` — Attaches bearer tokens from a token store.
  - `RefreshTokenInterceptor` — Automatically refreshes expired tokens on `401` responses and retries the request, signing out on failure. Requests failing together share one refresh, and a refresh token is never sent twice. When to refresh, when to sign out and whether to retry the refresh are configurable (see [Token refresh](#token-refresh)).
- **OIDC** — `OIDCClient` provides sign-in through `ASWebAuthenticationSession`, token refresh, and sign-out, along with token-expiry inspection (`TokenExpiry`) for PASETO/JWT.
- **Body encoding** — Supports JSON, `application/x-www-form-urlencoded` (`URLFormEncoder`), and streamed `multipart/form-data` (`MultipartFormDataEncoder`), including file uploads.

## Requirements

- iOS 15+, macOS 13+, watchOS 9+, tvOS 15+, visionOS 1+, and DriverKit 19+
- Swift 6.1 or later
- Supports both Swift 5 and Swift 6 language modes.

## Installation

Valensio is distributed through Swift Package Manager (SPM).

### Using Xcode

1. Open your project in Xcode.
2. Select **File → Add Package Dependencies...**
3. Enter the repository URL: `https://github.com/Valensas/Valensio.git`
4. Select the desired version or version range.
5. Add the `Valensio` package product to your application target.

### Using Package.swift

Add Valensio to the `dependencies` array in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Valensas/Valensio.git", from: "1.0.0")
]
```

Then add `Valensio` to the dependencies of your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["Valensio"]
)
```

## Usage

```swift
import Valensio

let client = UrlHttpClient(
    baseUrl: URL(string: "https://api.example.com")!,
    decoder: JSONDecoder(),
    encoder: JSONEncoder()
)

// GET with a decoded response
let user: User = try await client.request(method: .get, path: "/me")

// POST with an encoded body
let created: Item = try await client.request(
    method: .post,
    path: "/items",
    body: NewItem(name: "Widget")
)
```

### Token refresh

`RefreshTokenInterceptor` takes a `RefreshTokenConfiguration`. Every option defaults to the original behaviour: refresh on any `401`, sign out on any refresh error or on a `401` after the refresh, and no retry.

```swift
let store = MyTokenStore()
let interceptors: [any HttpInterceptor] = [
    RefreshTokenInterceptor(
        refresher: MyTokenRefresher(),
        tokenStore: store,
        configuration: .init(
            refreshTrigger: .invalidTokenChallenge,        // only `WWW-Authenticate: Bearer error="invalid_token"`
            signOutPolicy: .onInvalidGrant,                // only `400 {"error": "invalid_grant"}` ends the session
            signOutOnUnauthorizedAfterRefresh: false,      // rethrow the 401, keep the tokens
            retryPolicy: RetryPolicy(maxRetries: 2, initialDelay: 1) // 503 → retry after 1s, then 2s
        )
    ),
    BearerTokenInterceptor(tokenStore: store),
]
```

When the sign-out policy keeps the session, the refresh error (for example a `URLError`) is rethrown to the caller. Share one `RefreshTokenInterceptor` instance between all clients that use the same tokens, so they also share its refresh. `HttpStatusError.headers` gives access to the response headers.

## Testing

> [!IMPORTANT]
> **Run the tests on iOS 17+ / macOS 14+ (e.g. "My Mac" or an iOS 17+ simulator).**

The networked test suites (`HttpClientTests`, `UrlHttpClientTests`) run against an **embedded, httpbin-style HTTP server** instead of a real network service. The server is implemented with [Hummingbird](https://github.com/hummingbird-project/hummingbird), added as a **test-only** dependency. It is never resolved or built for consumers of the `Valensio` library.

Hummingbird 2.x gates its API behind a custom availability macro (`macOS 14.0, iOS 17.0, tvOS 17.0, visionOS 1.0`). Even though the package links against lower deployment targets, the embedded server can only run on those newer OS versions.

On an **older destination** (such as the iOS 16 simulator), the networked suites fall back to a placeholder URL and fail with "Could not connect to the server."

The server starts lazily on a random free port the first time a test needs it and is shared across suites. Running a single networked suite therefore behaves the same as running the full target — there is no ordering dependency.

Run the tests with:

```sh
swift test
```

## License

Valensio is available under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for the full text.
