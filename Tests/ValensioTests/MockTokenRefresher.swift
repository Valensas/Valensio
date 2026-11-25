//
//  MockTokenRefresher.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//


import Foundation
import Valensio

final class MockTokenRefresher: TokenRefresher, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<Token, any Error>]
    private let delay: TimeInterval
    private let onCall: (@Sendable () -> Void)?
    private var _callCount = 0
    private var _refreshTokens: [String] = []

    var called: Bool { callCount > 0 }
    var callCount: Int { lock.withLock { _callCount } }
    /// The refresh tokens it was called with, in order.
    var refreshTokens: [String] { lock.withLock { _refreshTokens } }

    init(error: Bool = false) {
        self.results = [error ? .failure(HttpStatusError(status: 401, data: Data())) : .success(MockTokenStore.newToken)]
        self.delay = 0
        self.onCall = nil
    }

    /// Answers each call with the next of `results`, repeating the last one once they run out.
    init(results: [Result<Token, any Error>], delay: TimeInterval = 0, onCall: (@Sendable () -> Void)? = nil) {
        precondition(!results.isEmpty)
        self.results = results
        self.delay = delay
        self.onCall = onCall
    }

    func getToken(fromRefreshToken token: String) async throws -> Token {
        let result: Result<Token, any Error> = lock.withLock {
            _callCount += 1
            _refreshTokens.append(token)
            return results.count > 1 ? results.removeFirst() : results[0]
        }
        onCall?()
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return try result.get()
    }
}
