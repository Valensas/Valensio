//
//  Error.swift
//  Valensio
//
//  Created by Moray Baruh on 25.02.2025.
//

import Foundation

public enum ClientError: Error {
    case urlNotConvertiable
    case urlComponentNotConvertible
    case noResponseData
    case unexpectedUrlResponse
    case noUrlResponse
}

public enum FileError: Error {
    case cannotRead
    case cannotOpenStream
}

public struct HttpStatusError: Error {
    public let status: Int
    public let data: Data
    /// The response headers, as sent by the server.
    public let headers: [String: String]

    public init(status: Int, data: Data, headers: [String: String] = [:]) {
        self.status = status
        self.data = data
        self.headers = headers
    }

    /// The value of the header named `name`, compared case-insensitively.
    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

public enum OIDCError: Error {
    case codeNotFound
    case invalidToken
    case signedOut
}
