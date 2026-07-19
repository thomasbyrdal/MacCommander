//
//  DuplicateFinderService.swift
//  MacCommander
//

import CryptoKit
import Foundation

nonisolated struct DuplicateFile: Identifiable, Sendable, Hashable {
    let id: URL
    let url: URL
    let size: Int64
}

nonisolated struct DuplicateGroup: Identifiable, Sendable, Hashable {
    var id: String { checksum }
    let checksum: String
    let size: Int64
    let files: [DuplicateFile]

    var wastedBytes: Int64 {
        size * Int64(max(files.count - 1, 0))
    }
}

nonisolated struct DuplicateScanResult: Sendable {
    let root: URL
    let groups: [DuplicateGroup]
    let scannedFileCount: Int

    var duplicateFileCount: Int {
        groups.reduce(0) { $0 + $1.files.count }
    }

    var wastedBytes: Int64 {
        groups.reduce(0) { $0 + $1.wastedBytes }
    }
}

nonisolated struct DuplicateScanOptions: Sendable {
    var includeHidden: Bool = false
    var minimumSize: Int64 = 1
}

nonisolated enum DuplicateFinderService {
    static func findDuplicates(
        in root: URL,
        options: DuplicateScanOptions = DuplicateScanOptions(),
        progress: (@Sendable (Int) -> Void)? = nil
    ) async throws -> DuplicateScanResult {
        try await Task.detached(priority: .userInitiated) {
            try scanSync(root: root, options: options, progress: progress)
        }.value
    }

    private static func scanSync(
        root: URL,
        options: DuplicateScanOptions,
        progress: (@Sendable (Int) -> Void)?
    ) throws -> DuplicateScanResult {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileOperationError.invalidPath(root.path)
        }

        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .fileSizeKey,
            .isHiddenKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: options.includeHidden
                ? [.skipsPackageDescendants]
                : [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return DuplicateScanResult(root: root, groups: [], scannedFileCount: 0)
        }

        var bySize: [Int64: [URL]] = [:]
        var scanned = 0

        while let next = enumerator.nextObject() as? URL {
            let values = try next.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true, values.isDirectory != true else { continue }
            let size = Int64(values.fileSize ?? 0)
            guard size >= options.minimumSize else { continue }
            bySize[size, default: []].append(next)
            scanned += 1
            if scanned.isMultiple(of: 250) {
                progress?(scanned)
            }
        }

        var byHash: [String: (size: Int64, files: [DuplicateFile])] = [:]

        for (size, urls) in bySize where urls.count > 1 {
            for url in urls {
                do {
                    let digest = try sha256(of: url)
                    var entry = byHash[digest] ?? (size: size, files: [])
                    entry.files.append(DuplicateFile(id: url, url: url, size: size))
                    byHash[digest] = entry
                } catch {
                    continue
                }
            }
        }

        let groups = byHash
            .filter { $0.value.files.count > 1 }
            .map { DuplicateGroup(checksum: $0.key, size: $0.value.size, files: $0.value.files) }
            .sorted { lhs, rhs in
                if lhs.wastedBytes == rhs.wastedBytes {
                    return lhs.size > rhs.size
                }
                return lhs.wastedBytes > rhs.wastedBytes
            }

        progress?(scanned)
        return DuplicateScanResult(root: root, groups: groups, scannedFileCount: scanned)
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = try? handle.read(upToCount: 1024 * 1024)
            guard let chunk, !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
