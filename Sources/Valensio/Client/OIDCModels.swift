//
//  OIDCModels.swift
//  Valensio
//
//  Created by Moray Baruh on 25.02.2025.
//

import Foundation

public struct OIDCConfiguration: Codable, Sendable {
    public let authorizationEndpoint: URL
    public let tokenEndpoint: URL
    public let revocationEndpoint: URL
    public let endSessionEndpoint: URL

    public init(authorizationEndpoint: URL, tokenEndpoint: URL, revocationEndpoint: URL, endSessionEndpoint: URL) {
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.revocationEndpoint = revocationEndpoint
        self.endSessionEndpoint = endSessionEndpoint
    }
}

public struct Token: Equatable, Codable, Sendable {
    public let accessToken: String
    public let idToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let refreshToken: String?
    public let refreshExpiresIn: Int?

    public init(
        accessToken: String,
        idToken: String,
        tokenType: String,
        expiresIn: Int,
        refreshToken: String?,
        refreshExpiresIn: Int?
    ) {
        self.accessToken = accessToken
        self.idToken = idToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.refreshExpiresIn = refreshExpiresIn
    }
}
