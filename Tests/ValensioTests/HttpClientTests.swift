//
//  HttpClientTests.swift
//  ValensioTests
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation
import Valensio
import Testing

struct HttpBinResponse<T: Decodable>: Decodable {
    let headers: [String: String]
    let args: [String: String]
    let form: [String: String]?
    let files: [String: String]?
    let json: T?
}

struct SampleRequest: Codable, Equatable {
    let intValue: Int
    let stringValue: String
    let dateValue: Date
    let boolValue: Bool
}

struct HttpClientTests {
    let baseUrl = URL.httpbin
    let client = HttpClient(decoder: JSONDecoder(), encoder: JSONEncoder())

    @Test
    func canSendGetRequest() async throws {
        try await client.request(method: .get, url: baseUrl.appendingPathComponent("/get"))
    }

    @Test
    func canSendPostRequest() async throws {
        try await client.request(method: .post, url: baseUrl.appendingPathComponent("/post"))
    }

    @Test
    func canSendPutRequest() async throws {
        try await client.request(method: .put, url: baseUrl.appendingPathComponent("/put"))
    }

    @Test
    func canSendPatchRequest() async throws {
        try await client.request(method: .patch, url: baseUrl.appendingPathComponent("/patch"))
    }

    @Test
    func canSendDeleteRequest() async throws {
        try await client.request(method: .delete, url: baseUrl.appendingPathComponent("/delete"))
    }

    @Test
    func canAddheaders() async throws {
        let response: HttpBinResponse<Nothing> = try await client.request(
            method: .get,
            url: baseUrl.appendingPathComponent("/get"),
            headers: ["hello": "world"]
        )
        #expect(response.headers["Hello"] == "world")
    }

    @Test
    func canAddQueryParams() async throws {
        let response: HttpBinResponse<Nothing> = try await client.request(
            method: .get,
            url: baseUrl.appendingPathComponent("/get"),
            params: ["hello": ["world"]]
        )
        #expect(response.args["hello"] == "world")
    }

    @Test
    func throwsOnClientError() async throws {
        let error = await #expect(throws: HttpStatusError.self) {
            try await client.request(method: .get, url: baseUrl.appendingPathComponent("/status/400"))
        }
        #expect(error?.status == 400)
    }

    @Test
    func throwsOnServerError() async throws {
        let error = await #expect(throws: HttpStatusError.self) {
            try await client.request(method: .get, url: baseUrl.appendingPathComponent("/status/500"))
        }
        #expect(error?.status == 500)
    }

    @Test
    func canEncodeAndDecode() async throws {
        let request = SampleRequest(intValue: 5, stringValue: "12", dateValue: Date.now, boolValue: true)
        let response: HttpBinResponse<SampleRequest> = try await client.request(
            method: .post,
            url: baseUrl.appendingPathComponent("/post"),
            body: request
        )
        #expect(response.json == request)
    }

    @Test
    func canRunInterceptorsInOrder() async throws {
        class Interceptor: HttpInterceptor {
            var callTime: Date? = nil

            func intercept(request: HttpRequest, chain: (HttpRequest) async throws -> HttpResponse) async throws -> HttpResponse {
                callTime = Date.now
                return try await chain(request)
            }
        }

        let interceptor1 = Interceptor()
        let interceptor2 = Interceptor()

        let client = HttpClient(
            decoder: JSONDecoder(),
            encoder: JSONEncoder(),
            interceptors: [interceptor1, interceptor2]
        )
        try await client.request(method: .get, url: baseUrl.appendingPathComponent("/get"))
        #expect(interceptor1.callTime != nil)
        #expect(interceptor2.callTime != nil)
        #expect(interceptor1.callTime! < interceptor2.callTime!)
    }

    @Test
    func canUseUrlFormEncoding() async throws {
        let client = HttpClient(decoder: JSONDecoder(), encoder: URLFormEncoder())
        let request = SampleRequest(intValue: 10, stringValue: "hello world", dateValue: Date.now, boolValue: true)
        let response: HttpBinResponse<Nothing> = try await client.request(
            method: .post,
            url: baseUrl.appendingPathComponent("/post"),
            body: request
        )
        #expect(response.form?["intValue"] == "10")
        #expect(response.form?["stringValue"] == "hello world")
        #expect(response.form?["boolValue"] == "true")
    }

    @Test
    func canUploadFile() async throws {
        let file = File(data: Data("Hello World".utf8), filename: "file.txt")
        let client = HttpClient(decoder: JSONDecoder(), encoder: MultipartFormDataEncoder())
        let response: HttpBinResponse<Nothing> = try await client.request(
            method: .post,
            url: baseUrl.appendingPathComponent("/post"),
            body: ["file": file]
        )
        #expect(response.files?["file"] == "Hello World")
    }
}
