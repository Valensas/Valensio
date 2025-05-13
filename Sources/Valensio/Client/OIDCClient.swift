//
//  OIDCClient.swift
//  Valensio
//
//  Created by Moray Baruh on 25.02.2025.
//

import Foundation
import OSLog
import _AuthenticationServices_SwiftUI


@available(iOS 16.4, *)
@available(tvOS 16.4, *)
@available(macOS 13.3, *)
public protocol UIAuthenticator {
    func authenticate(
        using url: URL,
        callbackURLScheme: String,
        preferredBrowserSession: WebAuthenticationSession.BrowserSession?
    ) async throws -> URL
}

@available(iOS 16.4, *)
@available(tvOS 16.4, *)
@available(macOS 13.3, *)
extension WebAuthenticationSession: UIAuthenticator {
}

public class OIDCClient: TokenRefresher, @unchecked Sendable {
    public let issuer: URL
    public let client: HttpClient
    public let clientId: String
    public let clientSecret: String
    public let basicAuth: String
    public let loginRedirectUrl: URL

    private var _configuration: OIDCConfiguration?
    private var configurationTask: Task<OIDCConfiguration, Error>?
    private let logger = Logger()

    public init(client: HttpClient, issuer: URL, clientId: String, clientSecret: String, appScheme: String) {
        self.issuer = issuer
        self.clientId = clientId
        self.clientSecret = clientSecret
        var loginRedirectComponents = URLComponents()
        loginRedirectComponents.scheme = appScheme
        loginRedirectComponents.path = "/login"
        self.loginRedirectUrl = loginRedirectComponents.url!

        self.basicAuth = Data("\(clientId):\(clientSecret)".utf8).base64EncodedString()
        self.client = client
    }

    public convenience init(issuer: URL, clientId: String, clientSecret: String, appScheme: String) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.init(
            client: HttpClient(decoder: decoder, encoder: URLFormEncoder()),
            issuer: issuer,
            clientId: clientId,
            clientSecret: clientSecret,
            appScheme: appScheme
        )
    }

    public func configuration() async throws -> OIDCConfiguration {
        if let _configuration {
            return _configuration
        }
        if let configurationTask {
            return try await configurationTask.value
        }

        let task: Task<OIDCConfiguration, Error> = Task {
            try await client.request(
                method: .get,
                url: issuer.appendingPathComponent("/.well-known/openid-configuration")
            )
        }
        defer {
            self.configurationTask = nil
        }
        configurationTask = task
        let configuration = try await task.value
        self._configuration = configuration
        return configuration
    }

    @available(iOS 16.4, *)
    @available(tvOS 16.4, *)
    @available(macOS 13.3, *)
    public func signIn(using authenticator: UIAuthenticator, locales: [String]?) async throws -> Token {
        let config = try await configuration()
        guard var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false) else {
            logger
                .warning("Authorization endpoint cannot be converted to URLComponents: \(config.authorizationEndpoint)")
            throw ClientError.urlNotConvertiable
        }

        components.queryItems = [
            "response_type": "code",
            "client_id": clientId,
            "redirect_uri": loginRedirectUrl.absoluteString,
            "scope": "openid email profile",
            "ui_locales": (locales ?? ([Locale.current.identifier] + Locale.preferredLanguages))
                .joined(separator: " ")
        ].map {
            URLQueryItem(name: $0.key, value: $0.value)
        }

        guard let url = components.url else {
            logger.warning("Cannot convert URLComponents \(components.description) to URL")
            throw ClientError.urlNotConvertiable
        }

        let returnUrl = try await authenticator.authenticate(
            using: url,
            callbackURLScheme: loginRedirectUrl.scheme!,
            preferredBrowserSession: .shared
        )

        let callbackQueryItems = URLComponents(url: returnUrl, resolvingAgainstBaseURL: false)?.queryItems
        guard let code = callbackQueryItems?.filter({ $0.name == "code" }).first?.value else {
            logger.warning("login callback URL does not contain code: \(url.absoluteString)")
            throw OIDCError.codeNotFound
        }
        return try await getToken(fromCode: code)
    }

    public func getToken(fromCode code: String) async throws -> Token {
        let configuration = try await configuration()

        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": loginRedirectUrl.absoluteString
        ]
        return try await client.request(
            method: .post,
            url: configuration.tokenEndpoint,
            body: body,
            headers: ["Authorization": "Basic \(basicAuth)"]
        )
    }

    public func getToken(fromRefreshToken token: String) async throws -> Token {
        let configuration = try await configuration()

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": token
        ]
        return try await client.request(
            method: .post,
            url: configuration.tokenEndpoint,
            body: body,
            headers: ["Authorization": "Basic \(basicAuth)"]
        )
    }

    public func signOut(token: Token) async throws {
        let config = try await configuration()

        try await client.request(method: .get, url: config.endSessionEndpoint, params: [
            "id_token_hint": [token.idToken],
            "client_id": [clientId]
        ])
    }
}
