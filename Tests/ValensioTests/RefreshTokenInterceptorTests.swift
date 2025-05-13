//
//  RefreshTokenInterceptorTests.swift
//  ValensioTests
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation
import Valensio
import Testing

class RefreshTokenInterceptorTests {
    @Test
    func doesNotDoAnythingOnSuccess() async throws {
        let refresher = MockTokenRefresher()
        let tokenStore = MockTokenStore()

        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: tokenStore)

        let request = HttpRequest(urlRequest: URLRequest(url: URL.httpbin), body: nil)
        let _ = try await interceptor.intercept(request: request) { request in
            return HttpResponse(urlResponse: URLResponse(), data: Data())
        }
        #expect(!refresher.called)
    }

    @Test
    func refreshesTokenAndRetriesOnUnauthorized() async throws {
        let refresher = MockTokenRefresher()
        let tokenStore = MockTokenStore()

        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: tokenStore)

        let request = HttpRequest(urlRequest: URLRequest(url: URL.httpbin), body: nil)
        let _ = try await interceptor.intercept(request: request) { request in
            if refresher.called {
                return HttpResponse(urlResponse: URLResponse(), data: Data())
            } else {
                throw HttpStatusError(status: 401, data: Data())
            }
        }

        #expect(refresher.called)
        #expect(tokenStore.token == MockTokenStore.newToken)
    }

    @Test
    func signsOutOnFailedRefresh() async throws {
        let refresher = MockTokenRefresher(error: true)
        let tokenStore = MockTokenStore()

        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: tokenStore)

        var chainCalled = 0
        await #expect(throws: OIDCError.signedOut) {
            let request = HttpRequest(urlRequest: URLRequest(url: URL.httpbin), body: nil)
            let _ = try await interceptor.intercept(request: request) { _ in
                chainCalled += 1
                if chainCalled == 1 {
                    throw HttpStatusError(status: 401, data: Data())
                }
                return HttpResponse(urlResponse: URLResponse(), data: Data())
            }
        }

        #expect(chainCalled == 1)
        #expect(refresher.called)
        #expect(tokenStore.token == nil)
    }

    @Test
    func signsOutAfterSuccessfulRefreshAndUnauthorized() async throws {
        let refresher = MockTokenRefresher()
        let tokenStore = MockTokenStore()

        let interceptor = RefreshTokenInterceptor(refresher: refresher, tokenStore: tokenStore)

        var chainCalled = 0
        await #expect(throws: OIDCError.signedOut) {
            let request = HttpRequest(urlRequest: URLRequest(url: URL.httpbin), body: nil)
            let _ = try await interceptor.intercept(request: request) { _ in
                chainCalled += 1
                throw HttpStatusError(status: 401, data: Data())
            }
        }

        #expect(chainCalled == 2)
        #expect(refresher.called)
        #expect(tokenStore.token == nil)
    }
}
