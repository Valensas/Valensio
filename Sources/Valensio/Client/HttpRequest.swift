//
//  HttpRequest.swift
//  Valensio
//
//  Created by Moray Baruh on 7.05.2025.
//

import Foundation

public struct HttpRequest {
    public let urlRequest: URLRequest
    public let body: HttpBody?

    public init(urlRequest: URLRequest, body: HttpBody?) {
        self.urlRequest = urlRequest
        self.body = body
    }
}
