//
//  FileItem.swift
//  MacCommander
//

import Foundation
import UniformTypeIdentifiers

/// Represents a single file or directory entry in a panel listing.
nonisolated struct FileItem: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool
    let isSymbolicLink: Bool
    let isHidden: Bool
    let size: Int64
    let modificationDate: Date?
    let creationDate: Date?
    let permissions: String?
    let contentType: UTType?
    /// Precomputed for list rendering — avoid formatter work in SwiftUI body.
    let displaySize: String
    let displayDate: String
    let displayType: String

    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    var isParentEntry: Bool {
        name == ".."
    }

    static func makeDisplayType(isDirectory: Bool, pathExtension: String) -> String {
        if isDirectory { return "Folder" }
        let ext = pathExtension.lowercased()
        return ext.isEmpty ? "File" : ext.uppercased()
    }
}

extension FileItem {
    /// Synthetic ".." entry for navigating to the parent directory.
    nonisolated static func parentEntry(of directory: URL) -> FileItem {
        let parent = directory.deletingLastPathComponent()
        return FileItem(
            id: parent.appendingPathComponent(".."),
            url: parent,
            name: "..",
            isDirectory: true,
            isSymbolicLink: false,
            isHidden: false,
            size: 0,
            modificationDate: nil,
            creationDate: nil,
            permissions: nil,
            contentType: .folder,
            displaySize: "",
            displayDate: "—",
            displayType: "Folder"
        )
    }
}
