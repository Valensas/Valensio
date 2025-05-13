//
//  MultipartFormDataEncoderTests.swift
//  ValensioTests
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation
import Valensio
import Testing

struct MultipartSample: Encodable {
    let file: File
    let stringValue: String
    let intValue: Int
    let stringArray: [String]
    let dictionary: [String: String]
    let nestedDictionary: [String: [String: String]]
    let dateValue: Date
    let nilValue: String? = nil
}

extension MultipartFormData {
    func part(named name: String) -> MultipartPart? {
        parts.first { $0.headers["content-disposition"]?.contains("name=\"\(name)\"") ?? false }
    }

    func parts(named name: String) -> [MultipartPart] {
        parts.filter { $0.headers["content-disposition"]?.contains("name=\"\(name)\"") ?? false }
    }
}

class MultipartFormDataEncoderTests {
    @Test
    func canEncode() throws {
        let sample = MultipartSample(
            file: .init(url: Bundle.module.url(forResource: "Sample File", withExtension: "txt")!),
            stringValue: "Hello World",
            intValue: 42,
            stringArray: ["hello", "world"],
            dictionary: ["hello": "world"],
            nestedDictionary: ["hello": ["hello": "world"]],
            dateValue: Date.now
        )
        let encoder = MultipartFormDataEncoder()
        let formData: MultipartFormData = try encoder.encode(sample)
        #expect(formData.part(named: "file")?.data.readAll() == "Hello World\n")
        #expect(formData.part(named: "stringValue")?.data.readAll() == sample.stringValue)
        #expect(formData.part(named: "intValue")?.data.readAll() == sample.intValue.description)
        let stringArrayParts = formData.parts(named: "stringArray[]").map(\.data).map { $0.readAll() }
        #expect(stringArrayParts == sample.stringArray)
        #expect(formData.part(named: "nestedDictionary[hello][hello]")?.data.readAll() == "world")
        #expect(
            formData
                .part(named: "dateValue")?.data
                .readAll() == sample.dateValue.timeIntervalSinceReferenceDate.description
        )
        #expect(formData.part(named: "nilValue") == nil)
    }
}


