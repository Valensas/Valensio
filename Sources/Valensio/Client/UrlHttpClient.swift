//
//  UrlHttpClient.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//


import Foundation

open class UrlHttpClient: HttpClient {
    public let baseUrl: URL

    public init(
        baseUrl: URL,
        session: URLSession = URLSession.shared,
        decoder: HttpBodyDecoder,
        encoder: HttpBodyEncoder,
        interceptors: [any HttpInterceptor] = []
    ) {
        self.baseUrl = baseUrl
        super.init(session: session, decoder: decoder, encoder: encoder, interceptors: interceptors)
    }

    // Both request and response bodies present
    public func request<Request: Encodable, Response: Decodable>(
        method: HttpMethod,
        path: String,
        body: Request,
        params: [String: [String]] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await request(
            method: method,
            url: baseUrl.appendingPathComponent(path),
            body: body,
            params: params,
            headers: headers
        )
    }
}
