//
//  HttpClient+Convinience.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation

extension HttpClient {
    // Both request and response bodies absent
    public func request(
        method: HttpMethod,
        url: URL,
        params: [String: [String]] = [:],
        headers: [String: String] = [:]
    ) async throws {
        let _: Nothing = try await request(
            method: method,
            url: url,
            body: Nothing.instance,
            params: params,
            headers: headers
        )
    }

    // Request body absent, response body present
    public func request<Response: Decodable>(
        method: HttpMethod,
        url: URL,
        params: [String: [String]] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await request(
            method: method,
            url: url,
            body: Nothing.instance,
            params: params,
            headers: headers
        )
    }

    // Request body present, response body absent
    public func request<Request: Encodable>(
        method: HttpMethod,
        url: URL,
        body: Request,
        params: [String: [String]] = [:],
        headers: [String: String] = [:]
    ) async throws {
        let _: Nothing = try await request(method: method, url: url, body: body, params: params, headers: headers)
    }
}
