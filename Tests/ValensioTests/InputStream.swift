//
//  InputStream.swift
//  Valensio
//
//  Created by Moray Baruh on 7.05.2025.
//


import Foundation

extension InputStream {
    func readAll() -> String {
        var data = Data()
        var buffer = Array<UInt8>(repeating: 0, count: 4096)
        if streamStatus == .notOpen {
            open()
        }
        while hasBytesAvailable {
            let bytesRead = read(&buffer, maxLength: buffer.count)
            if bytesRead > 0 {
                data.append(&buffer, count: bytesRead)
            }
            if let error = streamError {
                fatalError("stream error: \(error)")
            }

        }
        close()
        return String(data: data, encoding: .utf8)!
    }
}
