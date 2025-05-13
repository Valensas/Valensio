//
//  Coding.swift
//  Valensio
//
//  Created by Moray Baruh on 21.02.2025.
//

import OSLog
import Foundation

public protocol HttpBodyDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable
}

extension JSONDecoder: HttpBodyDecoder { }



public protocol HttpBodyEncoder {
    func encode<T>(_ value: T) throws -> HttpBody where T: Encodable
}

extension JSONEncoder: HttpBodyEncoder {
    public func encode<T>(_ value: T) throws -> HttpBody where T: Encodable {
        let stream = InputStream(data: try encode(value))
        return .init(
            stream: stream,
            contentType: "application/json",
            write: nil
        )
    }
}
