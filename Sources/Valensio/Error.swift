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

    public init(status: Int, data: Data) {
        self.status = status
        self.data = data
    }
}

public enum OIDCError: Error {
    case codeNotFound
    case invalidToken
    case signedOut
}
