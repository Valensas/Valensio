//
//  MultipartFormDataEncoder.swift
//  Valensio
//
//  Created by Moray Baruh on 27.03.2025.
//

import Foundation

public class MultipartFormDataEncoder {
    /// Defines available strategies to use when encoding key names.
    public enum KeyEncodingStrategy {
        /// Converts keys into snake_case.
        case convertToSnakeCase
        /// Uses keys as they are defined, without modifying them.
        case useDefaultKeys
        /// Uses a custom coding strategy defined by the closed provided.
        case custom(([CodingKey]) -> CodingKey)
    }

    /// Defines available strategies when encoding `Date` instances.
    public enum DateEncodingStrategy {
        /// Encodes by `encode(to:)` on the date instance.
        case deferredToDate
        /// Encodes an integer with the number of seconds since midnight UTC on January 1, 1970.
        case secondsSince1970
        /// Encodes an integer with the number of milliseconds since midnight UTC on January 1, 1970.
        case millisecondsSince1970
        /// Encodes the date with the provided `ISO8601DateFormatter`.
        case iso8601(ISO8601DateFormatter)
        /// Encodes the date with the provided `DateFormatter`.
        case formatted(DateFormatter)
        /// Delegates the encoding to the closure provided.
        case custom((Date, Encoder) throws -> Void)
    }

    /// Defines available strategies when encoding `Data` instances.
    public enum DataEncodingStrategy {
        /// Encode the data as is.
        case raw
        /// Encodes the data using Base 64.
        case base64
        /// Delegates the encoding to the closure provided.
        case custom((Data, Encoder) throws -> Void)
    }

    public enum NilEncodingStrategy {
        case none
        case empty
        case string
    }

    struct Options {
        var keyEncodingStrategy: KeyEncodingStrategy
        var dateEncodingStrategy: DateEncodingStrategy
        var dataEncodingStrategy: DataEncodingStrategy
        var nilEncodingStrategy: NilEncodingStrategy
    }

    var options: Options

    /// The strategy to use for encoding key names. Defaults to `KeyEncodingStrategy.useDefaultKeys`.
    public var keyEncodingStrategy: KeyEncodingStrategy {
        get { return options.keyEncodingStrategy }
        set { options.keyEncodingStrategy = newValue }
    }

    /// The strategy to use for encoding `Date` instances. Defaults to `DateEncodingStrategy.deferredToDate`.
    public var dateEncodingStrategy: DateEncodingStrategy {
        get { return options.dateEncodingStrategy }
        set { options.dateEncodingStrategy = newValue }
    }

    /// The strategy to use for encoding `Data` instances. Defaults to `DataEncodingStrategy.raw`.
    public var dataEncodingStrategy: DataEncodingStrategy {
        get { return options.dataEncodingStrategy }
        set { options.dataEncodingStrategy = newValue }
    }

    public var nilEncodingStrategy: NilEncodingStrategy {
        get { return options.nilEncodingStrategy }
        set { options.nilEncodingStrategy = newValue }
    }

    /// Creates a new `MultipartFormDataEncoder`.
    public init() {
        self.options = Options(
            keyEncodingStrategy: .useDefaultKeys,
            dateEncodingStrategy: .deferredToDate,
            dataEncodingStrategy: .raw,
            nilEncodingStrategy: .none
        )
    }

    public func encode<T>(_ value: T) throws -> MultipartFormData where T: Encodable {
        let boundary = "boundary-\(UUID().uuidString)"
        let formData = MultipartFormData(boundary: boundary)
        let encoder = _MultipartFormDataEncoder(
            multipartFormData: formData,
            options: options,
            codingPath: []
        )
        try encoder.encode(value)
        return formData
    }
}

extension MultipartFormDataEncoder: HttpBodyEncoder {
    public func encode<T>(_ value: T) throws -> HttpBody where T: Encodable {
        let formData: MultipartFormData = try encode(value)

        var inputStream: InputStream?
        var outputStream: OutputStream?

        Stream
            .getBoundStreams(
                withBufferSize: 4096,
                inputStream: &inputStream,
                outputStream: &outputStream
            )

        guard let input = inputStream, let output = outputStream else {
            fatalError("Failed to create input and output streams.")
        }

        output.schedule(in: .current, forMode: .default)
        output.open()

        return .init(stream: input, contentType: formData.contentType) {
            try formData.write(to: output)
            output.close()
        }
    }
}

private class _MultipartFormDataEncoder: Encoder {
    let multipartFormData: MultipartFormData
    let options: MultipartFormDataEncoder.Options

    var codingPath: [any CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    init(multipartFormData: MultipartFormData, options: MultipartFormDataEncoder.Options, codingPath: [any CodingKey]) {
        self.multipartFormData = multipartFormData
        self.options = options
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        .init(_KeyedEncodingContainer(encoder: self, codingPath: codingPath))
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        _UnkeyedEncodingContainer(referencing: self)
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        self
    }
}

extension _MultipartFormDataEncoder: SingleValueEncodingContainer {
    func encodeNil() throws {
        switch options.nilEncodingStrategy {
        case .none:
            break
        case .empty:
            multipartFormData.append("", withName: codingPath.flatten(with: options.keyEncodingStrategy))
        case .string:
            multipartFormData.append("null", withName: codingPath.flatten(with: options.keyEncodingStrategy))
        }
    }

    func encode(_ value: Bool) throws {
        multipartFormData
            .append(
                Data((value ? "true" : "false").utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: Int) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: Int8) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: Int16) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: Int32) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: Int64) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: UInt) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: UInt8) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: UInt16) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: UInt32) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: UInt64) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: Float) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: Double) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode(_ value: String) throws {
        multipartFormData
            .append(
                Data(value.description.utf8),
                withName: codingPath.flatten(with: options.keyEncodingStrategy)
            )
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        if let file = value as? File {
            switch file.type {
            case .data(let data, let filename):
                multipartFormData
                    .append(data, withName: codingPath.flatten(with: options.keyEncodingStrategy), fileName: filename)
            case .url(let url):
                try multipartFormData.append(url, withName: codingPath.flatten(with: options.keyEncodingStrategy))
            }
        } else if let date = value as? Date {
            try encode(date)
        } else {
            let nestedEncoder = _MultipartFormDataEncoder(
                multipartFormData: multipartFormData,
                options: options,
                codingPath: codingPath
            )
            try value.encode(to: nestedEncoder)
        }
    }
}

extension _MultipartFormDataEncoder {
    func encode(_ value: Date) throws {
        switch options.dateEncodingStrategy {
        case .deferredToDate:
            try value.encode(to: self)
        case .secondsSince1970:
            try encode(value.timeIntervalSince1970)
        case .millisecondsSince1970:
            try encode(value.timeIntervalSince1970 * 1000.0)
        case .iso8601(let formatter):
            try encode(formatter.string(from: value))
        case .formatted(let formatter):
            try encode(formatter.string(from: value))
        case .custom(let callback):
            try callback(value, self)
        }
    }

    func encode(_ value: Data) throws {
        switch options.dataEncodingStrategy {
        case .raw:
            multipartFormData.append(value, withName: codingPath.flatten(with: options.keyEncodingStrategy))
        case .base64:
            multipartFormData
                .append(
                    value.base64EncodedString(),
                    withName: codingPath.flatten(with: options.keyEncodingStrategy)
                )
        case .custom(let callback):
            try callback(value, self)
        }
    }
}

extension _MultipartFormDataEncoder {
    fileprivate func encoder(for key: any CodingKey) -> _ReferencingEncoder {
        .init(referencing: self, key: key)
    }

    fileprivate func encoder(at index: Int) -> _ReferencingEncoder {
        return .init(referencing: self, at: index)
    }
}

private class _ReferencingEncoder: _MultipartFormDataEncoder {
    private enum Reference {
        case object(String)
        case array(Int)
    }

    private let encoder: _MultipartFormDataEncoder
    private let reference: Reference

    fileprivate init(referencing encoder: _MultipartFormDataEncoder, key: CodingKey) {
        self.encoder = encoder
        reference = .object(key.stringValue)
        super.init(
            multipartFormData: encoder.multipartFormData,
            options: encoder.options,
            codingPath: encoder.codingPath + [key]
        )
    }

    fileprivate init(referencing encoder: _MultipartFormDataEncoder, at index: Int) {
        self.encoder = encoder
        reference = .array(index)
        super.init(
            multipartFormData: encoder.multipartFormData,
            options: encoder.options,
            codingPath: encoder.codingPath + [GenericCodingKey(intValue: index)]
        )
    }
}

private class _KeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _MultipartFormDataEncoder
    var codingPath: [CodingKey]

    init(encoder: _MultipartFormDataEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        try encoder.encoder(for: key).encode(value)
    }

    func encodeNil(forKey key: Key) throws {
        switch encoder.options.nilEncodingStrategy {
        case .none:
            break
        case .empty:
            encoder.multipartFormData
                .append("", withName: (codingPath + [key]).flatten(with: encoder.options.keyEncodingStrategy))
        case .string:
            encoder.multipartFormData
                .append("null", withName: (codingPath + [key]).flatten(with: encoder.options.keyEncodingStrategy))
        }
    }

    func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        encoder.encoder(for: key).container(keyedBy: keyType)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        encoder.encoder(for: key).unkeyedContainer()
    }

    func superEncoder() -> any Encoder {
        _MultipartFormDataEncoder(
            multipartFormData: encoder.multipartFormData,
            options: encoder.options,
            codingPath: codingPath + [GenericCodingKey(stringValue: "super")]
        )
    }

    func superEncoder(forKey key: Key) -> any Encoder {
        _MultipartFormDataEncoder(
            multipartFormData: encoder.multipartFormData,
            options: encoder.options,
            codingPath: codingPath + [key]
        )
    }

}

private class _UnkeyedEncodingContainer: UnkeyedEncodingContainer {
    private let encoder: _MultipartFormDataEncoder

    fileprivate var codingPath: [CodingKey] {
        encoder.codingPath
    }
    private var currentEncoder: _ReferencingEncoder {
        encoder.encoder(at: count)
    }

    var count: Int = 0

    init(referencing encoder: _MultipartFormDataEncoder) {
        self.encoder = encoder
    }

    // MARK: - Swift.UnkeyedEncodingContainer Meth

    func encodeNil() throws {
        try currentEncoder.encodeNil()
        count += 1
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        try currentEncoder.encode(value)
        count += 1
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        return currentEncoder.container(keyedBy: type)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        currentEncoder.unkeyedContainer()
    }

    func superEncoder() -> Encoder {
        currentEncoder
    }
}
