//
//  RefreshTokenPolicyTests.swift
//  ValensioTests
//

import Foundation
import Valensio
import Testing

/// Covers `RefreshTokenConfiguration` and the single-flight / stale-token behaviour of `RefreshTokenInterceptor`.
struct RefreshTokenPolicyTests {
    private let request = HttpRequest(urlRequest: URLRequest(url: URL.httpbin), body: nil)
    private let ok = HttpResponse(urlResponse: URLResponse(), data: Data())

    /// The settings mobile apps use to match the OAuth refresh rules on Android.
    private let oauthConfiguration = RefreshTokenConfiguration(
        refreshTrigger: .invalidTokenChallenge,
        signOutPolicy: .onInvalidGrant,
        signOutOnUnauthorizedAfterRefresh: false,
        retryPolicy: RetryPolicy(maxRetries: 2, initialDelay: 0.01)
    )

    private static func status(_ code: Int, body: String = "", headers: [String: String] = [:]) -> HttpStatusError {
        HttpStatusError(status: code, data: Data(body.utf8), headers: headers)
    }

    private static let invalidToken = status(401, headers: ["www-authenticate": #"Bearer realm="api", error="invalid_token", error_description="expired""#])
    private static let invalidGrant = status(400, body: #"{"error":"invalid_grant","error_description":"used"}"#)

    /// Fails with `failure` while the store holds the old token, succeeds otherwise.
    private func chain(_ store: MockTokenStore, failure: HttpStatusError = Self.invalidToken) -> (HttpRequest) async throws -> HttpResponse {
        { [ok] _ in
            if store.token == MockTokenStore.oldToken { throw failure }
            return ok
        }
    }

    // MARK: Retry policy

    @Test
    func retriesRefreshOn503() async throws {
        let refresher = MockTokenRefresher(results: [.failure(Self.status(503)), .failure(Self.status(503)), .success(MockTokenStore.newToken)])
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        _ = try await interceptor.intercept(request: request, chain: chain(store))

        #expect(refresher.callCount == 3)
        #expect(store.token == MockTokenStore.newToken)
    }

    @Test
    func stopsRetryingAfterMaxRetriesAndKeepsSession() async throws {
        let refresher = MockTokenRefresher(results: [.failure(Self.status(503))])
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        let error = await #expect(throws: HttpStatusError.self) {
            _ = try await interceptor.intercept(request: request, chain: chain(store))
        }

        #expect(error?.status == 503)
        #expect(refresher.callCount == 3)
        #expect(store.token == MockTokenStore.oldToken)
    }

    @Test
    func doesNotRetryByDefault() async throws {
        let refresher = MockTokenRefresher(results: [.failure(Self.status(503)), .success(MockTokenStore.newToken)])
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store)

        await #expect(throws: OIDCError.signedOut) {
            _ = try await interceptor.intercept(request: request, chain: chain(store, failure: Self.status(401)))
        }

        #expect(refresher.callCount == 1)
        #expect(store.token == nil)
    }

    @Test
    func doesNotRetryOtherStatuses() async throws {
        let refresher = MockTokenRefresher(results: [.failure(Self.status(500)), .success(MockTokenStore.newToken)])
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        await #expect(throws: HttpStatusError.self) {
            _ = try await interceptor.intercept(request: request, chain: chain(store))
        }

        #expect(refresher.callCount == 1)
    }

    // MARK: Sign-out policy

    @Test
    func keepsSessionOnNetworkError() async throws {
        let refresher = MockTokenRefresher(results: [.failure(URLError(.notConnectedToInternet))])
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        let error = await #expect(throws: URLError.self) {
            _ = try await interceptor.intercept(request: request, chain: chain(store))
        }

        #expect(error?.code == .notConnectedToInternet)
        #expect(store.token == MockTokenStore.oldToken)
    }

    @Test
    func signsOutOnInvalidGrant() async throws {
        let refresher = MockTokenRefresher(results: [.failure(Self.invalidGrant)])
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        await #expect(throws: OIDCError.signedOut) {
            _ = try await interceptor.intercept(request: request, chain: chain(store))
        }

        #expect(store.token == nil)
    }

    @Test
    func keepsSessionOnOtherOAuthErrors() async throws {
        let refresher = MockTokenRefresher(results: [.failure(Self.status(400, body: #"{"error":"invalid_request"}"#))])
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        await #expect(throws: HttpStatusError.self) {
            _ = try await interceptor.intercept(request: request, chain: chain(store))
        }

        #expect(store.token == MockTokenStore.oldToken)
    }

    @Test
    func keepsSessionOnUnauthorizedAfterRefreshWhenConfigured() async throws {
        let refresher = MockTokenRefresher()
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        var chainCalls = 0
        let error = await #expect(throws: HttpStatusError.self) {
            _ = try await interceptor.intercept(request: request) { _ in
                chainCalls += 1
                throw Self.invalidToken
            }
        }

        #expect(error?.status == 401)
        #expect(chainCalls == 2)
        #expect(store.token == MockTokenStore.newToken)
    }

    // MARK: Refresh trigger

    @Test
    func invalidTokenChallengeIgnoresOtherUnauthorized() async throws {
        let refresher = MockTokenRefresher()
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        for failure in [Self.status(401), Self.status(401, headers: ["WWW-Authenticate": #"Bearer error="insufficient_scope""#])] {
            let error = await #expect(throws: HttpStatusError.self) {
                _ = try await interceptor.intercept(request: request, chain: chain(store, failure: failure))
            }
            #expect(error?.status == 401)
        }

        #expect(!refresher.called)
        #expect(store.token == MockTokenStore.oldToken)
    }

    @Test
    func invalidTokenChallengeRefreshes() async throws {
        let refresher = MockTokenRefresher()
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        _ = try await interceptor.intercept(
            request: request,
            chain: chain(store, failure: Self.status(401, headers: ["WWW-Authenticate": "Bearer error=invalid_token"]))
        )

        #expect(refresher.refreshTokens == ["old-refresh"])
        #expect(store.token == MockTokenStore.newToken)
    }

    // MARK: Single flight and stale tokens

    @Test
    func concurrentFailuresShareOneRefresh() async throws {
        let refresher = MockTokenRefresher(results: [.success(MockTokenStore.newToken)], delay: 0.1)
        let store = MockTokenStore()
        let interceptor = UncheckedBox(RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    let request = HttpRequest(urlRequest: URLRequest(url: URL.httpbin), body: nil)
                    _ = try await interceptor.value.intercept(request: request) { _ in
                        if store.token == MockTokenStore.oldToken { throw Self.invalidToken }
                        return HttpResponse(urlResponse: URLResponse(), data: Data())
                    }
                }
            }
            try await group.waitForAll()
        }

        #expect(refresher.callCount == 1)
        #expect(store.token == MockTokenStore.newToken)
    }

    @Test
    func requestSentWithReplacedTokenRetriesWithoutRefreshing() async throws {
        let refresher = MockTokenRefresher()
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        var chainCalls = 0
        _ = try await interceptor.intercept(request: request) { [ok] _ in
            chainCalls += 1
            if chainCalls == 1 {
                store.token = MockTokenStore.newToken // another request refreshed while this one was out
                throw Self.invalidToken
            }
            return ok
        }

        #expect(!refresher.called)
        #expect(chainCalls == 2)
    }

    @Test
    func neverSendsAUsedRefreshTokenTwice() async throws {
        let refresher = MockTokenRefresher(results: [.success(MockTokenStore.newToken), .failure(Self.invalidGrant)])
        let store = MockTokenStore()
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        _ = try await interceptor.intercept(request: request, chain: chain(store))
        // A request that read the store before the first refresh was stored comes back with the old token.
        store.token = MockTokenStore.oldToken
        _ = try await interceptor.intercept(request: request, chain: chain(store))

        #expect(refresher.callCount == 1)
        #expect(store.token == MockTokenStore.newToken)
    }

    @Test
    func loginDuringRefreshWins() async throws {
        let store = MockTokenStore()
        let refresher = MockTokenRefresher(results: [.success(MockTokenStore.newToken)], delay: 0.05) {
            store.token = MockTokenStore.loginToken
        }
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        _ = try await interceptor.intercept(request: request, chain: chain(store))

        #expect(store.token == MockTokenStore.loginToken)
    }

    @Test
    func failedRefreshDoesNotSignOutANewLogin() async throws {
        let store = MockTokenStore()
        let refresher = MockTokenRefresher(results: [.failure(Self.invalidGrant)], delay: 0.05) {
            store.token = MockTokenStore.loginToken
        }
        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: store, configuration: oauthConfiguration)

        await #expect(throws: OIDCError.signedOut) {
            _ = try await interceptor.intercept(request: request, chain: chain(store))
        }

        #expect(store.token == MockTokenStore.loginToken)
    }
}

private final class UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
