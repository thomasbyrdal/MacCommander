//
//  CompareService.swift
//  MacCommander
//

import Foundation

nonisolated enum CompareEntryKind: String, Sendable, CaseIterable {
    case onlyLeft
    case onlyRight
    case identical
    case differ

    var title: String {
        switch self {
        case .onlyLeft: "Only Left"
        case .onlyRight: "Only Right"
        case .identical: "Identical"
        case .differ: "Different"
        }
    }
}

nonisolated struct CompareEntry: Identifiable, Sendable, Hashable {
    var id: String { relativePath }
    let relativePath: String
    let kind: CompareEntryKind
    let leftURL: URL?
    let rightURL: URL?
    let leftSize: Int64?
    let rightSize: Int64?
    let leftModified: Date?
    let rightModified: Date?
}

nonisolated struct CompareOptions: Sendable {
    var includeHidden: Bool = false
    var directoriesOnly: Bool = false
}

nonisolated struct CompareResult: Sendable {
    let leftRoot: URL
    let rightRoot: URL
    let entries: [CompareEntry]

    var onlyLeftCount: Int { entries.filter { $0.kind == .onlyLeft }.count }
    var onlyRightCount: Int { entries.filter { $0.kind == .onlyRight }.count }
    var differCount: Int { entries.filter { $0.kind == .differ }.count }
    var identicalCount: Int { entries.filter { $0.kind == .identical }.count }
}

nonisolated enum CompareService {
    static func compareDirectories(
        left: URL,
        right: URL,
        options: CompareOptions = CompareOptions()
    ) async throws -> CompareResult {
        try await Task.detached(priority: .userInitiated) {
            let leftItems = try listRelative(root: left, options: options)
            let rightItems = try listRelative(root: right, options: options)

            let allKeys = Set(leftItems.keys).union(rightItems.keys).sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }

            var entries: [CompareEntry] = []
            for key in allKeys {
                let leftMeta = leftItems[key]
                let rightMeta = rightItems[key]

                switch (leftMeta, rightMeta) {
                case (let l?, nil):
                    entries.append(
                        CompareEntry(
                            relativePath: key,
                            kind: .onlyLeft,
                            leftURL: l.url,
                            rightURL: nil,
                            leftSize: l.size,
                            rightSize: nil,
                            leftModified: l.modified,
                            rightModified: nil
                        )
                    )
                case (nil, let r?):
                    entries.append(
                        CompareEntry(
                            relativePath: key,
                            kind: .onlyRight,
                            leftURL: nil,
                            rightURL: r.url,
                            leftSize: nil,
                            rightSize: r.size,
                            leftModified: nil,
                            rightModified: r.modified
                        )
                    )
                case (let l?, let r?):
                    let sameType = l.isDirectory == r.isDirectory
                    let sameSize = l.isDirectory || l.size == r.size
                    let sameDate: Bool = {
                        switch (l.modified, r.modified) {
                        case (nil, nil): return true
                        case (let a?, let b?): return abs(a.timeIntervalSince(b)) < 1
                        default: return false
                        }
                    }()
                    let kind: CompareEntryKind = (sameType && sameSize && sameDate) ? .identical : .differ
                    entries.append(
                        CompareEntry(
                            relativePath: key,
                            kind: kind,
                            leftURL: l.url,
                            rightURL: r.url,
                            leftSize: l.size,
                            rightSize: r.size,
                            leftModified: l.modified,
                            rightModified: r.modified
                        )
                    )
                case (nil, nil):
                    break
                }
            }

            return CompareResult(leftRoot: left, rightRoot: right, entries: entries)
        }.value
    }

    private struct ItemMeta: Sendable {
        let url: URL
        let isDirectory: Bool
        let size: Int64
        let modified: Date?
    }

    private static func listRelative(root: URL, options: CompareOptions) throws -> [String: ItemMeta] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileOperationError.invalidPath(root.path)
        }

        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .isHiddenKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: options.includeHidden ? [.skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return [:]
        }

        var result: [String: ItemMeta] = [:]
        let rootPath = root.standardizedFileURL.path

        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            let isDir = values.isDirectory ?? false
            if options.directoriesOnly, !isDir { continue }

            var relative = String(url.standardizedFileURL.path.dropFirst(rootPath.count))
            if relative.hasPrefix("/") {
                relative.removeFirst()
            }
            guard !relative.isEmpty else { continue }

            result[relative] = ItemMeta(
                url: url,
                isDirectory: isDir,
                size: Int64(values.fileSize ?? 0),
                modified: values.contentModificationDate
            )
        }

        return result
    }
}
