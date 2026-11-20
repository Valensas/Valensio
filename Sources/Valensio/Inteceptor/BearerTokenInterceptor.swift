//
//  BearerTokenInterceptor.swift
//  Valensio
//
//  Created by Moray Baruh on 10.04.2025.
//

import SwiftUI
import Foundation

public class BearerTokenInterceptor<Store: TokenStore>: HttpInterceptor {
    let tokenStore: Store

    public init(tokenStore: Store) {
        self.tokenStore = tokenStore
    }

    public func intercept(request: HttpRequest, chain: (HttpRequest) async throws -> HttpResponse) async throws -> HttpResponse {
        guard let token = self.tokenStore.token else {
            return try await chain(request)
        }

        var newRequest = request.urlRequest
        newRequest.setValue("Bearer \(token.bearerToken)", forHTTPHeaderField: "Authorization")
        return try await chain(.init(urlRequest: newRequest, body: request.body))
    }
}
