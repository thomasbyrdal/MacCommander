//
//  HexEditorDocument.swift
//  MacCommander
//

import Foundation
import Observation

@MainActor
@Observable
final class HexEditorDocument {
    let url: URL
    private(set) var bytes: [UInt8]
    private(set) var isDirty = false
    var errorMessage: String?
    var bytesPerRow: Int = 16

    init(url: URL) throws {
        self.url = url
        let data = try Data(contentsOf: url)
        self.bytes = Array(data)
    }

    var rowCount: Int {
        max((bytes.count + bytesPerRow - 1) / bytesPerRow, 1)
    }

    func row(at index: Int) -> (offset: Int, hex: String, ascii: String) {
        let start = index * bytesPerRow
        guard start < bytes.count else {
            return (start, String(repeating: "   ", count: bytesPerRow), String(repeating: " ", count: bytesPerRow))
        }
        let end = min(start + bytesPerRow, bytes.count)
        let slice = bytes[start..<end]

        let hex = slice.map { String(format: "%02X", $0) }.joined(separator: " ")
        let paddedHex = hex.padding(toLength: bytesPerRow * 3 - 1, withPad: " ", startingAt: 0)

        let ascii = String(slice.map { byte -> Character in
            (byte >= 32 && byte < 127) ? Character(UnicodeScalar(byte)) : "."
        })

        return (start, paddedHex, ascii)
    }

    func setByte(at offset: Int, value: UInt8) {
        guard bytes.indices.contains(offset) else { return }
        bytes[offset] = value
        isDirty = true
    }

    func setByte(at offset: Int, hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count == 2, let value = UInt8(cleaned, radix: 16) else { return }
        setByte(at: offset, value: value)
    }

    func save() throws {
        let data = Data(bytes)
        try data.write(to: url, options: .atomic)
        isDirty = false
        errorMessage = nil
    }
}
