//
//  OIDCClientTests.swift
//  ValensioTests
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation
import Testing
import Valensio
import _AuthenticationServices_SwiftUI

extension HTTPURLResponse {
    static func success(_ url: URL) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: 100,
            httpVersion: "1.1",
            headerFields: nil
        )!
    }
}

class MockOIDCServer: HttpInterceptor {
    let encoder = JSONEncoder()

    var requests: [(HttpRequest, String)] = []
    let mockToken = Token(
        accessToken: UUID().uuidString,
        idToken: UUID().uuidString,
        tokenType: "Bearer",
        expiresIn: 42,
        refreshToken: UUID().uuidString,
        refreshExpiresIn: 43
    )

    let mockRefreshedToken = Token(
        accessToken: UUID().uuidString,
        idToken: UUID().uuidString,
        tokenType: "Bearer",
        expiresIn: 42,
        refreshToken: UUID().uuidString,
        refreshExpiresIn: 43
    )

    func intercept(request: HttpRequest, chain: (HttpRequest) async throws -> HttpResponse) async throws -> HttpResponse {
        let body = request.body?.stream.readAll() ?? ""
        requests.append((request, body))

        switch request.urlRequest.url?.relativePath {
        case "/.well-known/openid-configuration":
            return HttpResponse(
                urlResponse: HTTPURLResponse.success(request.urlRequest.url!),
                data: try encoder
                    .encode(
                        OIDCConfiguration(
                            authorizationEndpoint: URL.httpbin.appendingPathComponent("/authorize"),
                            tokenEndpoint: URL.httpbin.appendingPathComponent("/token"),
                            revocationEndpoint: URL.httpbin.appendingPathComponent("/revoke"),
                            endSessionEndpoint: URL.httpbin.appendingPathComponent("/endSession")
                        )
                    )
            )
        case "/token":
            if body.contains("grant_type=authorization_code") {
                return HttpResponse(
                    urlResponse: HTTPURLResponse(
                        url: request.urlRequest.url!,
                        statusCode: 100,
                        httpVersion: "1.1",
                        headerFields: nil
                    )!,
                    data: try encoder.encode(mockToken)
                )
            } else if body.contains("grant_type=refresh_token") {
                return HttpResponse(
                    urlResponse: HTTPURLResponse.success(request.urlRequest.url!),
                    data: try encoder.encode(mockRefreshedToken)
                )
            } else {
                throw HttpStatusError(status: 400, data: Data())
            }
        case "/endSession":
            return HttpResponse(
                urlResponse: HTTPURLResponse(
                    url: request.urlRequest.url!,
                    statusCode: 100,
                    httpVersion: "1.1",
                    headerFields: nil
                )!,
                data: Data()
            )
        default:
            throw HttpStatusError(status: 404, data: Data())
        }
    }
}

@available(iOS 16.4, *)
@available(tvOS 16.4, *)
class MockUIAuthenticator: UIAuthenticator {
    func authenticate(using url: URL, callbackURLScheme: String, preferredBrowserSession: WebAuthenticationSession.BrowserSession?) async throws -> URL {
        var components = URLComponents()
        components.scheme = callbackURLScheme
        components.queryItems = [URLQueryItem(name: "code", value: "authorization_code")]
        return components.url!
    }
}

class OIDCClientTests {

    @Test
    @available(iOS 16.4, *)
    @available(tvOS 16.4, *)
    func canLogin() async throws {
        let mockServer = MockOIDCServer()
        let oidcClient = oidcClient(interceptors: [mockServer])
        let authenticator = MockUIAuthenticator()
        let token = try await oidcClient.signIn(using: authenticator, locales: nil)

        #expect(token == mockServer.mockToken)
        #expect(mockServer.requests.count == 2)
        #expect(mockServer.requests[0].0.urlRequest.url?.path() == "/.well-known/openid-configuration")
        #expect(mockServer.requests[1].0.urlRequest.url?.path() == "/token")
        #expect(mockServer.requests[1].1.contains("grant_type=authorization_code") == true)
    }

    @Test
    func canRefreshToken() async throws {
        let mockServer = MockOIDCServer()
        let oidcClient = oidcClient(interceptors: [mockServer])
        let token = try await oidcClient.getToken(fromRefreshToken: mockServer.mockToken.refreshToken!)

        #expect(token == mockServer.mockRefreshedToken)
        #expect(mockServer.requests.count == 2)
        #expect(
            mockServer
                .requests[0].0.urlRequest.url?.path  == "/.well-known/openid-configuration"
        )
        #expect(mockServer.requests[1].0.urlRequest.url?.path == "/token")
        #expect(mockServer.requests[1].1.contains("grant_type=refresh_token") == true)
        #expect(
            mockServer
                .requests[1].1.contains("refresh_token=\(mockServer.mockToken.refreshToken!)") == true
        )
    }

    @Test
    func canSignOut() async throws {
        let mockServer = MockOIDCServer()
        let oidcClient = oidcClient(interceptors: [mockServer])
        let token = mockServer.mockToken

        try await oidcClient.signOut(token: token)

        #expect(mockServer.requests.count == 2)
        #expect(mockServer.requests[1].0.urlRequest.url?.path == "/endSession")
        #expect(mockServer.requests[1].0.urlRequest.url?.query?.contains("client_id=client-id") == true)
        #expect(mockServer.requests[1].0.urlRequest.url?.query?.contains("id_token_hint=\(token.idToken)") == true)
    }

    func oidcClient(interceptors: [any HttpInterceptor]) -> OIDCClient {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let httpClient = HttpClient(decoder: decoder, encoder: URLFormEncoder(), interceptors: interceptors)
        return OIDCClient(
            client: httpClient,
            issuer: URL.httpbin,
            clientId: "client-id",
            clientSecret: "client-secret",
            appScheme: "valensio"
        )
    }
}
