//
//  MockTokenStore.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//


import Valensio

class MockTokenStore: TokenStore {
    static let oldToken = Token(accessToken: "old-token", idToken: "old-token", tokenType: "", expiresIn: 0, refreshToken: "", refreshExpiresIn: 0)
    static let newToken = Token(accessToken: "new-token", idToken: "new-token", tokenType: "", expiresIn: 0, refreshToken: "", refreshExpiresIn: 0)
    var token: Token? = oldToken
}
