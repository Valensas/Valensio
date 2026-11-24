//
//  OAuth2Interceptor.swift
//  Valensio
//
//  Created by Moray Baruh on 10.04.2025.
//

import OSLog
import Foundation

public protocol TokenRefresher<Credential>: Sendable {
    associatedtype Credential: BearerCredential
    func getToken(fromRefreshToken token: String) async throws -> Credential
}

public protocol TokenStore<Credential> {
    associatedtype Credential: BearerCredential
    var token: Credential? { get set }
}

/// Refreshes the token when a request fails with a status the ``RefreshTrigger`` accepts (any `401` by default), then
/// sends the request once more.
///
/// Requests failing together share one refresh, and a refresh token is never sent twice: a request that was sent with
/// a token another request has already replaced is retried with the current token instead of refreshing again. A
/// session stored while a refresh runs (e.g. the user logs in again) is kept over the refresh's result.
///
/// What happens when the refresh fails, or the retried request is still unauthorized, is set by
/// ``RefreshTokenConfiguration``; its defaults sign the user out in both cases.
public class RefreshTokenInterceptor<Refresher: TokenRefresher, Store: TokenStore>: HttpInterceptor
where Refresher.Credential == Store.Credential {
    public typealias Configuration = RefreshTokenConfiguration

    public let tokenRefresher: Refresher
    public var tokenStore: Store
    public let configuration: Configuration

    private let coordinator = RefreshCoordinator<Refresher>()
    private let logger = Logger()

    public init(refresher: Refresher, tokenStore: Store, configuration: Configuration = .init()) {
        self.tokenStore = tokenStore
        self.tokenRefresher = refresher
        self.configuration = configuration
    }

    public func intercept(
        request: HttpRequest,
        chain: (HttpRequest) async throws -> HttpResponse
    ) async throws -> HttpResponse {
        guard let sentCredential = tokenStore.token, sentCredential.refreshToken != nil else {
            return try await chain(request)
        }

        do {
            return try await chain(request)
        } catch let error as HttpStatusError {
            guard configuration.refreshTrigger.shouldRefresh(error) else {
                throw error
            }
            logger.info("Received status \(error.status), will try to refresh token")
            return try await refreshTokenAndRetry(
                staleBearer: sentCredential.bearerToken,
                request: request,
                chain: chain
            )
        }
    }

    private func refreshTokenAndRetry(
        staleBearer: String,
        request: HttpRequest,
        chain: (HttpRequest) async throws -> HttpResponse
    ) async throws -> HttpResponse {
        do {
            try await refreshToken(replacing: staleBearer)
        } catch {
            guard configuration.signOutPolicy.shouldSignOut(error) else {
                logger.warning("Error refreshing token, keeping the session: \(error)")
                throw error
            }
            logger.warning("Error refreshing token, signing out user: \(error)")
            signOut(ifStillUsing: staleBearer)
            throw OIDCError.signedOut
        }

        let retriedBearer = tokenStore.token?.bearerToken
        do {
            return try await chain(request)
        } catch let error as HttpStatusError
            where error.status == 401 && configuration.signOutOnUnauthorizedAfterRefresh {
            // Still getting 401 after refreshing the token.
            // There is nothing more we can do, log the user out.
            logger.info("Received status 401 after refreshing token, signing out user")
            if let retriedBearer {
                signOut(ifStillUsing: retriedBearer)
            }
            throw OIDCError.signedOut
        }
    }

    /// Replaces the credential whose bearer token is `staleBearer` with a refreshed one. Does nothing when the store
    /// already holds another credential: someone refreshed (or logged in) since the request was sent.
    private func refreshToken(replacing staleBearer: String) async throws {
        guard let current = tokenStore.token, current.bearerToken == staleBearer else {
            logger.info("Token was already replaced, retrying with the current one")
            return
        }
        guard let refreshToken = current.refreshToken else {
            throw OIDCError.invalidToken
        }

        let refreshed = try await coordinator.refresh(
            refreshToken: refreshToken,
            refresher: tokenRefresher,
            retryPolicy: configuration.retryPolicy
        )

        // Requests sharing this refresh all get here: the first one stores it, the others find it stored. A
        // credential stored in the meantime by anyone else (e.g. a new login) wins over the refresh.
        if tokenStore.token?.bearerToken == staleBearer {
            tokenStore.token = refreshed
            logger.info("Successfully refreshed token")
        }
    }

    /// Signs out unless the store holds another credential by now, so a session stored meanwhile isn't ended.
    private func signOut(ifStillUsing bearer: String) {
        guard tokenStore.token?.bearerToken == bearer else { return }
        tokenStore.token = nil
    }
}

// MARK: - Configuration

/// How a ``RefreshTokenInterceptor`` decides when to refresh, when to give up the session and whether to retry the
/// refresh. The defaults refresh on any `401`, sign out on any refresh error or on a `401` after the refresh, and
/// never retry the refresh.
public struct RefreshTokenConfiguration: Sendable {
    /// Which failed responses trigger a refresh.
    public var refreshTrigger: RefreshTrigger
    /// Which refresh errors end the session. Other errors are rethrown and the stored token is kept.
    public var signOutPolicy: SignOutPolicy
    /// Whether a `401` on the request sent with the refreshed token ends the session. When `false`, the error is
    /// rethrown and the token is kept.
    public var signOutOnUnauthorizedAfterRefresh: Bool
    /// How to retry a failed refresh call, or `nil` to not retry it.
    public var retryPolicy: RetryPolicy?

    public init(
        refreshTrigger: RefreshTrigger = .anyUnauthorized,
        signOutPolicy: SignOutPolicy = .always,
        signOutOnUnauthorizedAfterRefresh: Bool = true,
        retryPolicy: RetryPolicy? = nil
    ) {
        self.refreshTrigger = refreshTrigger
        self.signOutPolicy = signOutPolicy
        self.signOutOnUnauthorizedAfterRefresh = signOutOnUnauthorizedAfterRefresh
        self.retryPolicy = retryPolicy
    }
}

/// Decides whether a failed response should trigger a token refresh.
public struct RefreshTrigger: Sendable {
    private let predicate: @Sendable (HttpStatusError) -> Bool

    public init(_ predicate: @escaping @Sendable (HttpStatusError) -> Bool) {
        self.predicate = predicate
    }

    public func shouldRefresh(_ error: HttpStatusError) -> Bool {
        predicate(error)
    }

    /// Any `401`.
    public static let anyUnauthorized = RefreshTrigger { $0.status == 401 }

    /// A `401` whose `WWW-Authenticate` challenge says the token is no longer valid
    /// (`Bearer error="invalid_token"`, RFC 6750 §3.1). Other `401`s can't be fixed by a refresh.
    public static let invalidTokenChallenge = RefreshTrigger { error in
        guard error.status == 401, let challenge = error.header("WWW-Authenticate") else { return false }
        return challenge.hasAuthParam(name: "error", value: "invalid_token")
    }

    public static func custom(_ predicate: @escaping @Sendable (HttpStatusError) -> Bool) -> RefreshTrigger {
        RefreshTrigger(predicate)
    }
}

/// Decides whether a refresh error ends the session.
public struct SignOutPolicy: Sendable {
    private let predicate: @Sendable (any Error) -> Bool

    public init(_ predicate: @escaping @Sendable (any Error) -> Bool) {
        self.predicate = predicate
    }

    public func shouldSignOut(_ error: any Error) -> Bool {
        predicate(error)
    }

    /// Any refresh error ends the session.
    public static let always = SignOutPolicy { _ in true }

    /// Only an OAuth `invalid_grant` answer (a `400` with `{"error": "invalid_grant"}`, RFC 6749 §5.2) ends the
    /// session: the refresh token is expired, revoked or already used. Anything else (no connection, a timeout, a
    /// server error) keeps it, so a later request can refresh again.
    public static let onInvalidGrant = SignOutPolicy { error in
        guard let error = error as? HttpStatusError, error.status == 400 else { return false }
        let body = try? JSONDecoder().decode(OAuthErrorBody.self, from: error.data)
        return body?.error == "invalid_grant"
    }

    public static func custom(_ predicate: @escaping @Sendable (any Error) -> Bool) -> SignOutPolicy {
        SignOutPolicy(predicate)
    }
}

/// Retries a refresh call that failed with one of `statusCodes`, waiting `initialDelay` before the first retry and
/// twice as long before each next one.
public struct RetryPolicy: Sendable {
    public var maxRetries: Int
    public var initialDelay: TimeInterval
    public var statusCodes: Set<Int>

    public init(maxRetries: Int, initialDelay: TimeInterval = 1, statusCodes: Set<Int> = [503]) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.statusCodes = statusCodes
    }

    func shouldRetry(_ error: any Error, attempt: Int) -> Bool {
        guard attempt < maxRetries, let error = error as? HttpStatusError else { return false }
        return statusCodes.contains(error.status)
    }

    func delay(beforeRetry attempt: Int) -> TimeInterval {
        initialDelay * pow(2, Double(attempt))
    }
}

// MARK: - Internals

/// Runs at most one refresh at a time, and remembers the last one so a refresh token is never sent twice.
private actor RefreshCoordinator<Refresher: TokenRefresher> {
    private var inFlight: (refreshToken: String, task: Task<Refresher.Credential, any Error>)?
    private var lastRefresh: (refreshToken: String, credential: Refresher.Credential)?

    func refresh(
        refreshToken: String,
        refresher: Refresher,
        retryPolicy: RetryPolicy?
    ) async throws -> Refresher.Credential {
        if let lastRefresh, lastRefresh.refreshToken == refreshToken {
            return lastRefresh.credential
        }
        if let inFlight {
            if inFlight.refreshToken == refreshToken {
                return try await inFlight.task.value
            }
            // Another session's refresh: let it finish, then refresh this one.
            _ = try? await inFlight.task.value
            return try await refresh(refreshToken: refreshToken, refresher: refresher, retryPolicy: retryPolicy)
        }

        let task = Task {
            try await Self.refresh(refreshToken: refreshToken, refresher: refresher, retryPolicy: retryPolicy)
        }
        inFlight = (refreshToken, task)
        defer { inFlight = nil }

        let credential = try await task.value
        lastRefresh = (refreshToken, credential)
        return credential
    }

    private static func refresh(
        refreshToken: String,
        refresher: Refresher,
        retryPolicy: RetryPolicy?
    ) async throws -> Refresher.Credential {
        var attempt = 0
        while true {
            do {
                return try await refresher.getToken(fromRefreshToken: refreshToken)
            } catch {
                guard let retryPolicy, retryPolicy.shouldRetry(error, attempt: attempt) else { throw error }
                let delay = retryPolicy.delay(beforeRetry: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempt += 1
            }
        }
    }
}

/// The body of an OAuth error answer, e.g. `{"error": "invalid_grant"}`.
private struct OAuthErrorBody: Decodable {
    let error: String
}

private extension String {
    /// Whether this `WWW-Authenticate` value has the auth-param `name=value` (quoted or not) in any challenge.
    func hasAuthParam(name: String, value: String) -> Bool {
        let pattern = "(^|[\\s,])\(NSRegularExpression.escapedPattern(for: name))\\s*=\\s*\"?"
            + "\(NSRegularExpression.escapedPattern(for: value))\"?(?=$|[\\s,])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
        return regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) != nil
    }
}
