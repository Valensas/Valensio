//
//  BasicAuthInterceptor.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation

public class BasicAuthInterceptor: HttpInterceptor {
    let authorization: String

    public init(username: String, password: String) {
        self.authorization = "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
    }

    public func intercept(request: HttpRequest, chain: (HttpRequest) async throws -> HttpResponse) async throws -> HttpResponse {
        var newRequest = request.urlRequest
        newRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
        return try await chain(.init(urlRequest: newRequest, body: request.body))
    }
}
