//
//  BearerTokenInterceptorTests.swift
//  ValensioTests
//
//  Created by Moray Baruh on 6.05.2025.
//

import Testing
import Valensio
import Foundation

struct BearerTokenInterceptorTests {
    @Test
    func canAddBearerAuthorizationHeader() async throws {
        let tokenStore = MockTokenStore()
        let interceptor = BearerTokenInterceptor(tokenStore: tokenStore)
        var called = false
        let request = HttpRequest(urlRequest: URLRequest(url: URL.httpbin), body: nil)
        let _ = try await interceptor.intercept(request: request) { request in
            #expect(
                request.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer \(tokenStore.token!.idToken)"
            )
            called = true
            return HttpResponse(urlResponse: URLResponse(), data: Data())
        }
        #expect(called, "Expected chain to be called but wasn't")
    }

}
