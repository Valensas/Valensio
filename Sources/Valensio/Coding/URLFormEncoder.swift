//
//  URLFormEncoder.swift
//  Valensio
//
//  Created by Moray Baruh on 25.02.2025.
//
import Foundation



private class Ref<T> {
    var value: T

    init(value: T) {
        self.value = value
    }
}

public class URLFormEncoder {
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

    public func encode<T>(_ value: T) throws -> [URLQueryItem] where T: Encodable {
        let queryItems = Ref(value: [URLQueryItem]())
        let encoder = _URLFormEncoder(options: options, queryItems: queryItems)
        try encoder.encode(value)
        return queryItems.value
    }
}

extension URLFormEncoder: HttpBodyEncoder {
    public func encode<T>(_ value: T) throws -> HttpBody where T: Encodable {
        let queryItems: [URLQueryItem] = try encode(value)

        var components = URLComponents()
        components.queryItems = queryItems
        guard let encoded = components.percentEncodedQuery else {
            fatalError("Cannot extract percentEncodedQuery from URLComponents, this should not happen")
        }

        return .init(
            stream: InputStream(data: Data(encoded.utf8)),
            contentType: "application/x-www-form-urlencoded",
            write: nil
        )
    }
}

private class _URLFormEncoder: Encoder {
    let options: URLFormEncoder.Options
    var queryItems: Ref<[URLQueryItem]>

    var codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]

    init(options: URLFormEncoder.Options, queryItems: Ref<[URLQueryItem]>, codingPath: [any CodingKey] = []) {
        self.options = options
        self.codingPath = codingPath
        self.queryItems = queryItems
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

extension _URLFormEncoder: SingleValueEncodingContainer {
    func encodeNil() throws {
        switch options.nilEncodingStrategy {
        case .none:
            break
        case .empty:
            queryItems.value
                .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: nil))
        case .string:
            queryItems.value
                .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: "null"))
        }
    }

    func encode(_ value: Bool) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: Int) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: Int8) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: Int16) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: Int32) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: Int64) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: UInt) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: UInt8) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: UInt16) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: UInt32) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: UInt64) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: Float) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: Double) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value.description))
    }

    func encode(_ value: String) throws {
        queryItems.value
            .append(URLQueryItem(name: codingPath.flatten(with: options.keyEncodingStrategy), value: value))
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        if let date = value as? Date {
            try encode(date)
            return
        }
        let nestedEncoder = _URLFormEncoder(
            options: options,
            queryItems: queryItems,
            codingPath: codingPath
        )
        try value.encode(to: nestedEncoder)
    }
}

extension _URLFormEncoder {
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
}

extension _URLFormEncoder {
    fileprivate func encoder(for key: any CodingKey) -> _ReferencingEncoder {
        .init(referencing: self, key: key)
    }

    fileprivate func encoder(at index: Int) -> _ReferencingEncoder {
        return .init(referencing: self, at: index)
    }
}

private class _ReferencingEncoder: _URLFormEncoder {
    private enum Reference {
        case object(String)
        case array(Int)
    }

    private let encoder: _URLFormEncoder
    private let reference: Reference

    fileprivate init(referencing encoder: _URLFormEncoder, key: CodingKey) {
        self.encoder = encoder
        reference = .object(key.stringValue)
        super.init(
            options: encoder.options,
            queryItems: encoder.queryItems,
            codingPath: encoder.codingPath + [key]
        )
    }

    fileprivate init(referencing encoder: _URLFormEncoder, at index: Int) {
        self.encoder = encoder
        reference = .array(index)
        super.init(
            options: encoder.options,
            queryItems: encoder.queryItems,
            codingPath: encoder.codingPath + [GenericCodingKey(intValue: index)]
        )
    }
}

private class _KeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _URLFormEncoder
    var codingPath: [CodingKey]

    init(encoder: _URLFormEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        try encoder.encoder(for: key).encode(value)
    }

    func encodeNil(forKey key: Key) throws {
        let name = (codingPath + [key]).flatten(with: encoder.options.keyEncodingStrategy)
        switch encoder.options.nilEncodingStrategy {
        case .none:
            break
        case .empty:
            encoder.queryItems.value.append(URLQueryItem(name: name, value: nil))
        case .string:
            encoder.queryItems.value.append(URLQueryItem(name: name, value: "null"))
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
        _URLFormEncoder(
            options: encoder.options,
            queryItems: encoder.queryItems,
            codingPath: codingPath + [GenericCodingKey(stringValue: "super")]
        )
    }

    func superEncoder(forKey key: Key) -> any Encoder {
        _URLFormEncoder(
            options: encoder.options,
            queryItems: encoder.queryItems,
            codingPath: codingPath + [key]
        )
    }

}

private class _UnkeyedEncodingContainer: UnkeyedEncodingContainer {
    private let encoder: _URLFormEncoder

    fileprivate var codingPath: [CodingKey] {
        encoder.codingPath
    }
    private var currentEncoder: _ReferencingEncoder {
        encoder.encoder(at: count)
    }

    var count: Int = 0

    init(referencing encoder: _URLFormEncoder) {
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
