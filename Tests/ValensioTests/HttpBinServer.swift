//
//  HttpBinServer.swift
//  ValensioTests
//
//  Created by Ahmet Geymen on 20.11.2026.
//
//  An embedded, httpbin-style HTTP server used by the networked test suites
//  (`HttpClientTests`, `UrlHttpClientTests`) so they no longer depend on a real
//  `http://localhost:8080` service.
//
//  The server is started lazily on a random free port the first time any test
//  asks for its base URL, and it is shared across suites. Because startup is
//  lazy and self-contained, running a single suite in isolation works exactly
//  the same as running the whole test target — there is no ordering dependency.
//

import Foundation
import HTTPTypes
import Hummingbird
import NIOCore

/// Shared, lazily-started embedded httpbin stub.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
actor HttpBinServer {
    static let shared = HttpBinServer()

    private var startTask: Task<URL, Error>?

    /// Returns the base URL of the running server, starting it on first use.
    func baseURL() async throws -> URL {
        if let startTask {
            return try await startTask.value
        }
        let task = Task { try await Self.launch() }
        startTask = task
        return try await task.value
    }

    /// Boots a Hummingbird application on an ephemeral port and resolves once
    /// the server has bound and reported its address.
    private static func launch() async throws -> URL {
        let router = makeRouter()

        return try await withCheckedThrowingContinuation { continuation in
            let application = Application(
                router: router,
                configuration: ApplicationConfiguration(
                    address: .hostname("127.0.0.1", port: 0)
                ),
                onServerRunning: { channel in
                    let port = channel.localAddress?.port ?? 0
                    continuation.resume(returning: URL(string: "http://127.0.0.1:\(port)")!)
                }
            )

            // Run the server for the lifetime of the test process. It is torn
            // down automatically when the process exits.
            Task {
                do {
                    try await application.runService()
                } catch {
                    // If the server stops before binding, surface the failure.
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Routing

    private static func makeRouter() -> Router<BasicRequestContext> {
        let router = Router()

        router.get("get") { request, context in
            try await echo(request: request, context: context)
        }
        router.post("post") { request, context in
            try await echo(request: request, context: context)
        }
        router.put("put") { request, context in
            try await echo(request: request, context: context)
        }
        router.patch("patch") { request, context in
            try await echo(request: request, context: context)
        }
        router.delete("delete") { request, context in
            try await echo(request: request, context: context)
        }
        router.get("status/:code") { _, context in
            let code = context.parameters.get("code", as: Int.self) ?? 500
            return Response(status: .init(code: code))
        }

        return router
    }

    /// Builds an httpbin-style JSON response echoing the request's headers,
    /// query args, and (depending on content type) form / files / json body.
    private static func echo(request: Request, context: some RequestContext) async throws -> Response {
        var payload: [String: Any] = [:]

        // Headers, title-cased to match httpbin (e.g. `hello` -> `Hello`).
        var headers: [String: String] = [:]
        for field in request.headers {
            headers[titleCased(field.name.canonicalName)] = field.value
        }
        payload["headers"] = headers

        // Query arguments.
        payload["args"] = parseQueryPairs(request.uri.query.map { String($0) }, plusAsSpace: false)

        // Body, interpreted according to the content type.
        let bodyBuffer = try await request.body.collect(upTo: 16 * 1024 * 1024)
        let bodyData = Data(bodyBuffer.readableBytesView)
        let contentType = request.headers[.contentType] ?? ""

        if contentType.contains("application/json") {
            if !bodyData.isEmpty, let json = try? JSONSerialization.jsonObject(with: bodyData) {
                payload["json"] = json
            } else {
                payload["json"] = NSNull()
            }
        } else if contentType.contains("application/x-www-form-urlencoded") {
            payload["form"] = parseURLEncodedForm(bodyData)
            payload["json"] = NSNull()
        } else if contentType.contains("multipart/form-data") {
            let (form, files) = parseMultipart(bodyData, contentType: contentType)
            payload["form"] = form
            payload["files"] = files
            payload["json"] = NSNull()
        } else {
            payload["json"] = NSNull()
        }

        let data = try JSONSerialization.data(withJSONObject: payload)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(bytes: data))
        )
    }

    // MARK: - Parsing helpers

    private static func titleCased(_ name: String) -> String {
        name
            .split(separator: "-", omittingEmptySubsequences: false)
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: "-")
    }

    private static func parseURLEncodedForm(_ data: Data) -> [String: String] {
        parseQueryPairs(String(data: data, encoding: .utf8), plusAsSpace: true)
    }

    private static func parseQueryPairs(_ query: String?, plusAsSpace: Bool) -> [String: String] {
        guard let query, !query.isEmpty else { return [:] }
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let rawKey = String(parts[0])
            let rawValue = parts.count > 1 ? String(parts[1]) : ""
            let key = decode(rawKey, plusAsSpace: plusAsSpace)
            let value = decode(rawValue, plusAsSpace: plusAsSpace)
            result[key] = value
        }
        return result
    }

    private static func decode(_ string: String, plusAsSpace: Bool) -> String {
        let preprocessed = plusAsSpace ? string.replacingOccurrences(of: "+", with: " ") : string
        return preprocessed.removingPercentEncoding ?? preprocessed
    }

    /// Minimal multipart/form-data parser sufficient for the test fixtures:
    /// text fields are returned under `form`, parts with a `filename` under `files`.
    private static func parseMultipart(
        _ data: Data,
        contentType: String
    ) -> (form: [String: String], files: [String: String]) {
        var form: [String: String] = [:]
        var files: [String: String] = [:]

        guard
            let boundary = contentType
                .components(separatedBy: "boundary=")
                .last?
                .trimmingCharacters(in: .whitespaces),
            !boundary.isEmpty,
            let body = String(data: data, encoding: .utf8)
        else {
            return (form, files)
        }

        let marker = "--" + boundary
        for rawSegment in body.components(separatedBy: marker) {
            // Note: "\r\n" is a single Swift Character (grapheme cluster), so we
            // drop/trim by one Character, not two, to avoid eating adjacent bytes.
            var segment = rawSegment
            if segment.hasPrefix("\r\n") { segment = String(segment.dropFirst()) }
            // Skip the preamble ("") and the closing marker ("--").
            if segment.isEmpty || segment.hasPrefix("--") { continue }

            guard let headerRange = segment.range(of: "\r\n\r\n") else { continue }
            let headerBlock = String(segment[segment.startIndex..<headerRange.lowerBound])
            var value = String(segment[headerRange.upperBound...])
            if value.hasSuffix("\r\n") { value = String(value.dropLast()) }

            guard let disposition = headerBlock
                .split(separator: "\r\n")
                .first(where: { $0.lowercased().hasPrefix("content-disposition:") })
            else { continue }

            guard let name = quotedAttribute("name", in: String(disposition)) else { continue }
            if quotedAttribute("filename", in: String(disposition)) != nil {
                files[name] = value
            } else {
                form[name] = value
            }
        }

        return (form, files)
    }

    private static func quotedAttribute(_ attribute: String, in header: String) -> String? {
        guard let prefixRange = header.range(of: "\(attribute)=\"") else { return nil }
        let remainder = header[prefixRange.upperBound...]
        guard let closingQuote = remainder.firstIndex(of: "\"") else { return nil }
        return String(remainder[remainder.startIndex..<closingQuote])
    }
}
