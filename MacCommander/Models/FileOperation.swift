//
//  FileOperation.swift
//  MacCommander
//

import Foundation

nonisolated enum FileOperationKind: String, Sendable {
    case copy
    case move
    case delete
    case rename
    case duplicate
    case createFolder
    case createFile
    case createSymlink
    case compress
    case extract
}

nonisolated enum OverwritePolicy: String, CaseIterable, Sendable, Identifiable {
    case ask
    case overwrite
    case skip
    case rename

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: "Ask"
        case .overwrite: "Overwrite"
        case .skip: "Skip"
        case .rename: "Rename"
        }
    }
}

nonisolated struct FileOperationRequest: Identifiable, Sendable {
    let id: UUID
    let kind: FileOperationKind
    let sources: [URL]
    let destination: URL?
    var overwritePolicy: OverwritePolicy
    var permanentDelete: Bool

    init(
        id: UUID = UUID(),
        kind: FileOperationKind,
        sources: [URL],
        destination: URL? = nil,
        overwritePolicy: OverwritePolicy = .ask,
        permanentDelete: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.sources = sources
        self.destination = destination
        self.overwritePolicy = overwritePolicy
        self.permanentDelete = permanentDelete
    }
}

nonisolated struct FileOperationProgress: Sendable {
    var completedItems: Int
    var totalItems: Int
    var bytesTransferred: Int64
    var totalBytes: Int64
    var currentFileName: String
    var isCancelled: Bool
    var fractionCompleted: Double {
        guard totalBytes > 0 else {
            guard totalItems > 0 else { return 0 }
            return Double(completedItems) / Double(totalItems)
        }
        return Double(bytesTransferred) / Double(totalBytes)
    }
}

nonisolated enum FileOperationError: LocalizedError, Sendable {
    case cancelled
    case permissionDenied(URL)
    case sourceMissing(URL)
    case destinationExists(URL)
    case diskFull
    case invalidPath(String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Operation cancelled"
        case .permissionDenied(let url):
            "Permission denied: \(url.path)"
        case .sourceMissing(let url):
            "Item not found: \(url.path)"
        case .destinationExists(let url):
            "Already exists: \(url.path)"
        case .diskFull:
            "Disk is full"
        case .invalidPath(let path):
            "Invalid path: \(path)"
        case .underlying(let message):
            message
        }
    }
}
