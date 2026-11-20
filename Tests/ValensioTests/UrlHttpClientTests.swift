//
//  UrlHttpClientTests.swift
//  ValensioTests
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation
import Valensio
import Testing

class UrlHttpClientTests {
    let client: UrlHttpClient

    init() async throws {
        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *) {
            let baseURL = try await HttpBinServer.shared.baseURL()
            client = UrlHttpClient(baseUrl: baseURL, decoder: JSONDecoder(), encoder: JSONEncoder())
        } else {
            client = UrlHttpClient(baseUrl: URL.httpbin, decoder: JSONDecoder(), encoder: JSONEncoder())
        }
    }

	@Test
    func canRequest() async throws {
        try await client.request(method: .get, path: "/get")
    }

    @Test
    func canEncodeAndDecode() async throws {
        let request = SampleRequest(intValue: 5, stringValue: "12", dateValue: Date.now, boolValue: true)
        let response: HttpBinResponse<SampleRequest> = try await client.request(
            method: .post,
            path: "/post",
            body: request
        )
        #expect(response.json == request)
    }

    @Test
    func canEncode() async throws {
        let request = SampleRequest(intValue: 5, stringValue: "12", dateValue: Date.now, boolValue: true)
        try await client.request(
            method: .post,
            path: "/post",
            body: request
        )
    }

    @Test
    func canDecode() async throws {
        let _: HttpBinResponse<Nothing> = try await client.request(
            method: .post,
            path: "/post"
        )
    }
}
