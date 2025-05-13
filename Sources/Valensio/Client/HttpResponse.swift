//
//  HttpResponse.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation

public struct HttpResponse {
    public let urlResponse: URLResponse
    public let data: Data

    public init(urlResponse: URLResponse, data: Data) {
        self.urlResponse = urlResponse
        self.data = data
    }
}
