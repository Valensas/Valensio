//
//  File.swift
//  Valensio
//
//  Created by Moray Baruh on 18.03.2025.
//

import Foundation

public enum FileType {
    case data(Data, filename: String)
    case url(URL)
}

public struct File: Encodable {
    public let type: FileType

    public init(data: Data, filename: String) {
        self.type = .data(data, filename: filename)
    }

    public init(url: URL) {
        self.type = .url(url)
    }

    public func encode(to encoder: any Encoder) throws {
        fatalError("Cannot encode File to \(encoder.self), use multipart form encoding instead")
    }
}
