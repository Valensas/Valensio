//
//  MultipartFormData.swift
//  Valensio
//
//  Created by Moray Baruh on 27.03.2025.
//

import Foundation
import UniformTypeIdentifiers

extension Dictionary where Key == String {
    subscript(caseInsensitive key: Key) -> Value? {
        get {
            if let key = keys.first(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                return self[key]
            }
            return nil
        }
        set {
            if let key = keys.first(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                self[key] = newValue
            } else {
                self[key] = newValue
            }
        }
    }
}

extension URL {
    var mimeType: String {
        UTType(filenameExtension: pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}

public class MultipartPart {
    public let data: InputStream
    public let headers: [String: String]

    init(data: InputStream, headers: [String: String]) {
        data.open()
        self.data = data
        self.headers = headers
    }

    init(file: URL, headers: [String: String]) throws {
        guard let data = InputStream(url: file) else {
            throw FileError.cannotOpenStream
        }
        data.open()
        self.data = data
        var headers = headers
        if headers[caseInsensitive: "content-type"] == nil {
            headers["content-type"] = file.mimeType
        }
        self.headers = headers
    }

    deinit {
        data.close()
    }
}

public final class MultipartFormData: @unchecked Sendable {
    public let boundary: String

    public let contentType: String

    public private(set) var parts: [MultipartPart] = []

    init(boundary: String) {
        self.boundary = boundary
        self.contentType = "multipart/form-data; boundary=\(self.boundary)"
    }

    public func append(_ data: Data, withName name: String, fileName: String? = nil, contentType: String? = nil) {
        append(InputStream(data: data), withName: name, fileName: fileName, contentType: contentType)
    }

    public func append(_ string: String, withName name: String, fileName: String? = nil, contentType: String? = nil) {
        append(Data(string.utf8), withName: name, fileName: fileName, contentType: contentType)
    }

    public func append(_ data: InputStream, withName name: String, fileName: String? = nil, contentType: String? = nil) {
        var headers = [
            "content-disposition": contentDisposition(forName: name, fileName: fileName)
        ]
        if let contentType {
            headers["content-type"] = contentType
        } else if let fileName {
            headers["content-type"] = URL(string: fileName)?.mimeType
        }
        parts.append(.init(data: data, headers: headers))
    }

    public func append(_ file: URL, withName name: String, fileName: String? = nil, contentType: String? = nil) throws {
        var headers = [
            "content-disposition": contentDisposition(forName: name, fileName: fileName ?? file.lastPathComponent)
        ]
        if let contentType {
            headers["content-type"] = contentType
        }
        try parts.append(.init(file: file, headers: headers))
    }

    private func contentDisposition(forName name: String, fileName: String?) -> String {
        var contentDisosition = ["form-data", "name=\"\(name)\""]
        if let fileName {
            contentDisosition.append("filename=\"\(fileName)\"")
        }
        return contentDisosition.joined(separator: "; ")
    }
}

private extension String {
    static let crlf = "\r\n"
}

extension MultipartFormData {
    public func write(to outputStream: OutputStream) throws {
        try parts.forEach {
            try write("--" + boundary, to: outputStream)
            try write(.crlf, to: outputStream)
            try write($0, to: outputStream)
        }
        try write("--" + boundary, to: outputStream)
        try write("--", to: outputStream)
    }

    private func write(_ part: MultipartPart, to outputStream: OutputStream) throws {
        try part.headers.forEach { key, value in
            try write(key + ": " + value + .crlf, to: outputStream)
        }
        try write(.crlf, to: outputStream)
        try write(part.data, to: outputStream)
        try write(.crlf, to: outputStream)
    }

    private func write(_ data: Data, to outputStream: OutputStream) throws {
        var buffer = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &buffer, count: data.count)

        return try write(buffer, to: outputStream)
    }

    private func write(_ string: String, to outputStream: OutputStream) throws {
        return try write(Data(string.utf8), to: outputStream)
    }

    private func write(_ buffer: [UInt8], to outputStream: OutputStream, maxSize: Int? = nil) throws {
        var bytesToWrite = maxSize ?? buffer.count
        var buffer = buffer

        while bytesToWrite > 0 {
            let bytesWritten = outputStream.write(buffer, maxLength: bytesToWrite)

            if let error = outputStream.streamError {
                throw error
            }

            bytesToWrite -= bytesWritten

            if bytesToWrite > 0 {
                buffer = Array(buffer[bytesWritten..<buffer.count])
            }
        }
    }

    private func write(_ inputStream: InputStream, to outputStream: OutputStream) throws {
        precondition(inputStream.streamStatus == .open)
        var buffer: [UInt8] = .init(repeating: 0, count: 4096)
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
            try write(buffer, to: outputStream, maxSize: bytesRead)

            if let error = inputStream.streamError {
                throw error
            }
        }
    }
}
