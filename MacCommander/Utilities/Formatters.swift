//
//  Formatters.swift
//  MacCommander
//

import Foundation

enum Formatters {
    nonisolated static func sizeString(for item: FileItem) -> String {
        if item.isParentEntry { return "" }
        if item.isDirectory { return "—" }
        return byteCountString(item.size)
    }

    nonisolated static func dateString(for item: FileItem) -> String {
        guard let modificationDate = item.modificationDate else { return "—" }
        return dateString(modificationDate)
    }

    nonisolated static func byteCountString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    nonisolated static func dateString(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
