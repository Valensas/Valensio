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

public class RefreshTokenInterceptor<Refresher: TokenRefresher, Store: TokenStore>: HttpInterceptor
where Refresher.Credential == Store.Credential {
    public let tokenRefresher: Refresher
    public var tokenStore: Store

    private var refreshTokenTask: Task<Store.Credential, any Error>?
    private let logger = Logger()

    public init(refresher: Refresher, tokenStore: Store) {
        self.tokenStore = tokenStore
        self.tokenRefresher = refresher
    }

    public func intercept(
        request: HttpRequest,
        chain: (HttpRequest) async throws -> HttpResponse
    ) async throws -> HttpResponse {
        guard let refreshToken = self.tokenStore.token?.refreshToken else {
            return try await chain(request)
        }

        do {
            return try await chain(request)
        } catch let error as HttpStatusError {
            if error.status == 401 {
                logger.info("Received status 401, will try to refresh token")
                return try await refreshTokenAndRetry(
                    refreshToken: refreshToken,
                    request: request,
                    chain: chain
                )
            }

            throw error
        }
    }

    private func refreshTokenAndRetry(
        refreshToken: String,
        request: HttpRequest,
        chain: (HttpRequest) async throws -> HttpResponse
    ) async throws -> HttpResponse {
        do {
            try await self.refreshToken(token: refreshToken)
        } catch {
            logger.warning("Error refreshing token, singing out user: \(error)")
            tokenStore.token = nil
            throw OIDCError.signedOut
        }

        do {
            logger.info("Successfully refreshed token")
            return try await chain(request)
        } catch let error as HttpStatusError {
            // Still getting 401 after refreshing the token.
            // There is nothing more we can do, log the user out.
            if error.status == 401 {
                logger.info("Received status 401 after refreshing token, signing out user")
                tokenStore.token = nil
                throw OIDCError.signedOut
            }
            throw error
        }
    }

    private func refreshToken(token: String) async throws {
        // Prevent concurrent refreshes
        if let refreshTokenTask {
            let _ = try await refreshTokenTask.value
            return
        }

        let task = Task { [tokenRefresher] in
            try await tokenRefresher.getToken(fromRefreshToken: token)
        }

        refreshTokenTask = task
        defer {
            self.refreshTokenTask = nil
        }

        let token = try await task.value
        tokenStore.token = token
    }
}
