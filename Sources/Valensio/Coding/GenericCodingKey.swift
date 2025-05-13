//
//  GenericCodingKey.swift
//  Valensio
//
//  Created by Moray Baruh on 7.05.2025.
//


import Foundation

final class GenericCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }

    required init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    required init(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}
