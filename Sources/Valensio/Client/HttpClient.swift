//
//  HttpClient.swift
//  Valensio
//
//  Created by Moray Baruh on 21.02.2025.
//

import Foundation
import OSLog

open class HttpClient {
    public let session: URLSession
    public let decoder: HttpBodyDecoder
    public let encoder: HttpBodyEncoder
    public let interceptors: [any HttpInterceptor]
    public let logger = Logger()

    public init(
        session: URLSession = URLSession.shared,
        decoder: HttpBodyDecoder,
        encoder: HttpBodyEncoder,
        interceptors: [any HttpInterceptor] = []
    ) {
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
        self.interceptors = interceptors
    }

    // Both request and response bodies present
    public func request<Request: Encodable, Response: Decodable>(
        method: HttpMethod,
        url: URL,
        body: Request,
        params: [String: [String]] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        let httpRequest: HttpRequest

        do {
            httpRequest = try createHttpRequest(
                method: method,
                url: url,
                body: body,
                params: params,
                headers: headers
            )
        } catch {
            logger.debug("\(error.localizedDescription)")
            throw error
        }

        defer {
            httpRequest.body?.terminate()
        }

        let response = try await request(httpRequest)

        do {
            // We expect no response body, do not try to decode
            if let nothing = Nothing.instance as? Response {
                return nothing
            } else {
                let decodedData = try decoder.decode(Response.self, from: response.data)
                return decodedData
            }
        } catch {
            logger.debug("\(error)")
            throw error
        }

    }

    func uploadRequest(
        request: HttpRequest,
        uploader: RequestUploader
    ) async throws -> HttpResponse {
        try await withCheckedThrowingContinuation { continuation in
            uploader.continuation = continuation
            let task = session.uploadTask(withStreamedRequest: request.urlRequest)
            task.delegate = uploader
            task.resume()

            DispatchQueue.global(qos: .utility).async {
                do {
                    try request.body?.write?()
                } catch {
                    // Remove continuation to prevent double resume
                    uploader.continuation = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func request(_ request: HttpRequest) async throws -> HttpResponse {
        let uploader = RequestUploader(body: request.body?.stream)

        return try await runInterceptors(for: request, interceptors: interceptors) {
            let response: HttpResponse
            if request.body != nil {
                response = try await uploadRequest(request: $0, uploader: uploader)
            } else {
                let (data, urlResponse) = try await session.data(for: $0.urlRequest)
                response = HttpResponse(urlResponse: urlResponse, data: data)
            }
            try verifyResponse(request: $0.urlRequest, response: response)
            return response
        }
    }

    private func logHttpResponseError(data: Data, request: URLRequest, response: HTTPURLResponse) {
        let status = response.statusCode
        let method = request.httpMethod ?? ""
        let url = request.url?.absoluteString ?? ""
        logger.error("Response with unexpected HTTP status: \(status) from \(method) \(url)")
        if data.count > 0, let responseBody = String(data: data, encoding: .utf8) {
            logger.error("\(responseBody)")
        } else {
            logger.error("<<no response body>>")
        }
    }

    private func verifyResponse(
        request: URLRequest,
        response: HttpResponse
    ) throws {
        guard let httpResponse = response.urlResponse as? HTTPURLResponse else {
            let response = response.urlResponse.self.description
            logger.warning("Expected URLResponse to be an HTTPURLResponse but was \(response)")
            throw ClientError.unexpectedUrlResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        default:
            logHttpResponseError(data: response.data, request: request, response: httpResponse)
            throw HttpStatusError(status: httpResponse.statusCode, data: response.data)
        }
    }

    private func createHttpRequest(
        method: HttpMethod,
        url: URL,
        body: Encodable,
        params: [String: [String]] = [:],
        headers: [String: String] = [:]
    ) throws -> HttpRequest {
        let queryItems = params.sorted(by: { $0.key < $1.key }).flatMap { key, values in
            values.map {
                URLQueryItem(name: key, value: $0)
            }
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.warning("Could not convert \(url.absoluteString) to URLComponents")
            throw ClientError.urlNotConvertiable
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            logger.warning("Could not convert URLComponents \(components) to URL")
            throw ClientError.urlComponentNotConvertible
        }

        var urlRequest = URLRequest(url: url)

        urlRequest.httpMethod = method.rawValue

        headers.forEach {
            urlRequest.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        var httpBody: HttpBody?
        if method != .get && !(body is Nothing) {
            let encodedBody = try encoder.encode(body)
            urlRequest.setValue(encodedBody.contentType, forHTTPHeaderField: "content-type")
            httpBody = encodedBody
        } else if method == .get && !(body is Nothing) {
            logger.warning(
                "Body used for request GET \(url.absoluteString) will be ignored. GET requests do not support body."
            )
        }

        return HttpRequest(urlRequest: urlRequest, body: httpBody)
    }

    private func runInterceptors(
        for request: HttpRequest,
        interceptors: [any HttpInterceptor],
        destination: (HttpRequest) async throws -> HttpResponse
    ) async throws -> HttpResponse {
        guard let interceptor = interceptors.first else {
            return try await destination(request)
        }
        return try await interceptor.intercept(request: request) {
            try await runInterceptors(for: $0, interceptors: Array(interceptors[1...]), destination: destination)
        }
    }
}

