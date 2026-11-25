//
//  MockTokenStore.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//


import Foundation
import Valensio

final class MockTokenStore: TokenStore, @unchecked Sendable {
    static let oldToken = Token(accessToken: "old-token", idToken: "old-token", tokenType: "", expiresIn: 0, refreshToken: "old-refresh", refreshExpiresIn: 0)
    static let newToken = Token(accessToken: "new-token", idToken: "new-token", tokenType: "", expiresIn: 0, refreshToken: "new-refresh", refreshExpiresIn: 0)
    static let loginToken = Token(accessToken: "login-token", idToken: "login-token", tokenType: "", expiresIn: 0, refreshToken: "login-refresh", refreshExpiresIn: 0)

    private let lock = NSLock()
    private var _token: Token? = oldToken

    var token: Token? {
        get { lock.withLock { _token } }
        set { lock.withLock { _token = newValue } }
    }
}
