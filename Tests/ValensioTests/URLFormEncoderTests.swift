//
//  URLFormEncoderTests.swift
//  ValensioTests
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation
import Testing
import Valensio

struct URLFormSample: Encodable {
    let stringValue: String
    let intValue: Int
    let stringArray: [String]
    let dictionary: [String: String]
    let nestedDictionary: [String: [String: String]]
    let dateValue: Date
    let nilValue: String? = nil
}

extension Array where Element == URLQueryItem {
    func named(_ name: String) -> String? {
        first { $0.name == name }?.value
    }

    func allNamed(_ name: String) -> [String?] {
        filter { $0.name == name }.map(\.value)
    }
}

class URLFormEncoderTests {
    @Test
    func canEncode() throws {
        let encoder = URLFormEncoder()

        let sample = URLFormSample(
            stringValue: "Hello World",
            intValue: 42,
            stringArray: ["hello", "world"],
            dictionary: ["hello": "world"],
            nestedDictionary: ["hello": ["hello": "world"]],
            dateValue: Date.now
        )
        let encoded: [URLQueryItem] = try encoder.encode(sample)

        #expect(encoded.named("stringValue") == sample.stringValue)
        #expect(encoded.named("intValue") == sample.intValue.description)
        #expect(encoded.allNamed("stringArray[]") == sample.stringArray)
        #expect(encoded.named("dictionary[hello]") == "world")
        #expect(encoded.named("nestedDictionary[hello][hello]") == "world")
        #expect(encoded.named("dateValue") == sample.dateValue.timeIntervalSinceReferenceDate.description)
        #expect(encoded.named("nilValue") == nil)
    }
}
