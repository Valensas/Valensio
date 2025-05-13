//
//  UrlHttpClient+Convinience.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//


import Foundation

extension UrlHttpClient {
    // Both request and response bodies absent
    public func request(
        method: HttpMethod,
        path: String,
        params: [String: [String]] = [:],
        headers: [String: String] = [:]
    ) async throws {
        let _: Nothing = try await request(
            method: method,
            path: path,
            body: Nothing.instance,
            params: params,
            headers: headers
        )
    }

    // Request body absent, response body present
    public func request<Response: Decodable>(
        method: HttpMethod,
        path: String,
        params: [String: [String]] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await request(
            method: method,
            path: path,
            body: Nothing.instance,
            params: params,
            headers: headers
        )
    }

    // Request body present, response body absent
    public func request<Request: Encodable>(
        method: HttpMethod,
        path: String,
        body: Request,
        params: [String: [String]] = [:],
        headers: [String: String] = [:]
    ) async throws {
        let _: Nothing = try await request(method: method, path: path, body: body, params: params, headers: headers)
    }
}
