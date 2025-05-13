//
//  SnakeCaseTests.swift
//  ValensioTests
//
//  Created by Moray Baruh on 6.05.2025.
//

import Foundation
@testable import Valensio
import Testing

class SnakeCaseTests {
	@Test
    func canConvert() async throws {
        let mapping = [
            "helloWorld": "hello_world",
            "HelloWorld": "hello_world"
        ]
        mapping.forEach { key, value in
            #expect(key.convertToSnakeCase() == value)
        }
    }
}
