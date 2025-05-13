//
//  HttpBody.swift
//  Valensio
//
//  Created by Moray Baruh on 7.05.2025.
//


import OSLog
import Foundation

@preconcurrency
public class HttpBody {
    public let stream: InputStream
    public let contentType: String
    public let write: (() throws -> Void)?

    public init(stream: InputStream, contentType: String, write: (() throws -> Void)?) {
        self.stream = stream
        self.contentType = contentType
        self.write = write
    }

    public func terminate() {
        if stream.streamStatus != .closed {
            stream.close()
        }
    }
}
