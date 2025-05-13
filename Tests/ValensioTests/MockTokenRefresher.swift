//
//  MockTokenRefresher.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//


import Foundation
import Valensio

class MockTokenRefresher: TokenRefresher, @unchecked Sendable {
    let error: Bool
    private(set) var called = false

    init(error: Bool = false) {
        self.error = error
    }

    func getToken(fromRefreshToken token: String) async throws -> Token {
        called = true
        if error {
            throw HttpStatusError.init(status: 401, data: Data())
        } else {
            return MockTokenStore.newToken
        }
    }
}
