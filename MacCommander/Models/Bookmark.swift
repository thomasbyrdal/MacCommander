//
//  Bookmark.swift
//  MacCommander
//

import Foundation

nonisolated struct Bookmark: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var path: String

    var url: URL {
        URL(fileURLWithPath: path)
    }

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }

    init(url: URL, name: String? = nil) {
        self.id = UUID()
        self.name = name ?? url.lastPathComponent
        self.path = url.path
    }
}
