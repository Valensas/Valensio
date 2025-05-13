//
//  OAuth2Interceptor.swift
//  Valensio
//
//  Created by Moray Baruh on 10.04.2025.
//

import OSLog
import Foundation

public protocol TokenRefresher: Sendable {
    func getToken(fromRefreshToken token: String) async throws -> Token
}

public protocol TokenStore {
    var token: Token? { get set }
}

public class RefreshTokenInterceptor: HttpInterceptor {
    public let tokenRefresher: TokenRefresher
    public var tokenStore: TokenStore

    private var refreshTokenTask: Task<Token, any Error>?
    private let logger = Logger()

    public init(refresher: TokenRefresher, tokenStore: TokenStore) {
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
