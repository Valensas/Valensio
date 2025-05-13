//
//  Nothing.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//


import Foundation

public struct Nothing: Codable, Sendable {
    public static let instance = Nothing()

    private init() { }
}
