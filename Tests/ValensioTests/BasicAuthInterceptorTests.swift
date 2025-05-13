//
//  BasicAuthInterceptorTests.swift
//  ValensioTests
//
//  Created by Moray Baruh on 6.05.2025.
//

import Testing
import Valensio
import Foundation

struct BasicAuthInterceptorTests {
    @Test
    func canAddBasicAuthorizationHeader() async throws {
        let interceptor = BasicAuthInterceptor(username: "username", password: "password")
        var called = false
        let request = HttpRequest(urlRequest: URLRequest(url: URL.httpbin), body: nil)
        let _ = try await interceptor.intercept(request: request) { request in
            #expect(request.urlRequest.value(forHTTPHeaderField: "Authorization") == "Basic dXNlcm5hbWU6cGFzc3dvcmQ=")
            called = true
            return HttpResponse(urlResponse: URLResponse(), data: Data())
        }
        #expect(called, "Interceptor chain not called")
    }

}
