//
//  HttpInterceptor.swift
//  Valensio
//
//  Created by Moray Baruh on 10.04.2025.
//

import Foundation

public protocol HttpInterceptor {
    func intercept(
        request: HttpRequest,
        chain: (HttpRequest) async throws -> HttpResponse
    ) async throws -> HttpResponse
}
