//
//  FileService.swift
//  MacCommander
//

import Foundation
import UniformTypeIdentifiers

/// Marks service types that intentionally run off the main actor.
nonisolated protocol FileServiceProtocol: Sendable {
    func listDirectory(at url: URL, showHidden: Bool) async throws -> [FileItem]
    func fileExists(at url: URL) -> Bool
    func isDirectory(at url: URL) -> Bool
    func freeDiskSpace(at url: URL) -> Int64?
    func createDirectory(at url: URL) throws
    func createEmptyFile(at url: URL) throws
    func createSymbolicLink(at url: URL, pointingTo target: URL) throws
    func trashItems(_ urls: [URL]) throws
    func permanentlyDeleteItems(_ urls: [URL]) throws
    func renameItem(at url: URL, to newName: String) throws -> URL
    func duplicateItem(at url: URL) throws -> URL
    func copyItems(
        _ sources: [URL],
        to destinationDirectory: URL,
        overwritePolicy: OverwritePolicy,
        progress: @escaping @Sendable (FileOperationProgress) -> Void
    ) async throws
    func moveItems(
        _ sources: [URL],
        to destinationDirectory: URL,
        overwritePolicy: OverwritePolicy,
        progress: @escaping @Sendable (FileOperationProgress) -> Void
    ) async throws
    func compressItems(_ sources: [URL], to destinationURL: URL) throws
    func extractArchive(at url: URL, to destinationDirectory: URL) throws
}

nonisolated struct FileService: FileServiceProtocol {
    init() {}

    func listDirectory(at url: URL, showHidden: Bool) async throws -> [FileItem] {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw FileOperationError.invalidPath(url.path)
            }

            // Keep keys minimal — contentType/creationDate are expensive at scale.
            let resourceKeys: [URLResourceKey] = [
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .isHiddenKey,
                .fileSizeKey,
                .contentModificationDateKey
            ]

            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: showHidden ? [] : [.skipsHiddenFiles]
            )

            var items: [FileItem] = contents.compactMap { itemURL in
                Self.makeFileItem(from: itemURL)
            }

            let parent = url.deletingLastPathComponent()
            if parent.path != url.path {
                items.insert(FileItem.parentEntry(of: url), at: 0)
            }

            return items
        }.value
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    func freeDiskSpace(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        if let capacity = values?.volumeAvailableCapacityForImportantUsage {
            return capacity
        }
        if let capacity = values?.volumeAvailableCapacity {
            return Int64(capacity)
        }
        return nil
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }

    func createEmptyFile(at url: URL) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: url.path) else {
            throw FileOperationError.destinationExists(url)
        }
        let created = fileManager.createFile(atPath: url.path, contents: Data())
        if !created {
            throw FileOperationError.underlying("Could not create file at \(url.path)")
        }
    }

    func createSymbolicLink(at url: URL, pointingTo target: URL) throws {
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
    }

    func trashItems(_ urls: [URL]) throws {
        for url in urls {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        }
    }

    func permanentlyDeleteItems(_ urls: [URL]) throws {
        for url in urls {
            try FileManager.default.removeItem(at: url)
        }
    }

    func renameItem(at url: URL, to newName: String) throws -> URL {
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw FileOperationError.destinationExists(destination)
        }
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    func duplicateItem(at url: URL) throws -> URL {
        let destination = uniqueURL(for: url, suffix: " copy")
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    func copyItems(
        _ sources: [URL],
        to destinationDirectory: URL,
        overwritePolicy: OverwritePolicy,
        progress: @escaping @Sendable (FileOperationProgress) -> Void
    ) async throws {
        try await transfer(
            sources,
            to: destinationDirectory,
            overwritePolicy: overwritePolicy,
            move: false,
            progress: progress
        )
    }

    func moveItems(
        _ sources: [URL],
        to destinationDirectory: URL,
        overwritePolicy: OverwritePolicy,
        progress: @escaping @Sendable (FileOperationProgress) -> Void
    ) async throws {
        try await transfer(
            sources,
            to: destinationDirectory,
            overwritePolicy: overwritePolicy,
            move: true,
            progress: progress
        )
    }

    func compressItems(_ sources: [URL], to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        var arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent"]
        arguments.append(contentsOf: sources.map(\.path))
        arguments.append(destinationURL.path)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "Compression failed"
            throw FileOperationError.underlying(message)
        }
    }

    func extractArchive(at url: URL, to destinationDirectory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", url.path, destinationDirectory.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "Extraction failed"
            throw FileOperationError.underlying(message)
        }
    }

    // MARK: - Private

    private func transfer(
        _ sources: [URL],
        to destinationDirectory: URL,
        overwritePolicy: OverwritePolicy,
        move: Bool,
        progress: @escaping @Sendable (FileOperationProgress) -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let totalBytes = sources.reduce(Int64(0)) { partial, url in
                partial + (Self.allocatedSize(of: url, fileManager: fileManager) ?? 0)
            }

            var transferred: Int64 = 0
            for (index, source) in sources.enumerated() {
                try Task.checkCancellation()

                let destination = destinationDirectory.appendingPathComponent(source.lastPathComponent)
                progress(
                    FileOperationProgress(
                        completedItems: index,
                        totalItems: sources.count,
                        bytesTransferred: transferred,
                        totalBytes: totalBytes,
                        currentFileName: source.lastPathComponent,
                        isCancelled: false
                    )
                )

                if fileManager.fileExists(atPath: destination.path) {
                    switch overwritePolicy {
                    case .ask, .overwrite:
                        try? fileManager.removeItem(at: destination)
                    case .skip:
                        transferred += Self.allocatedSize(of: source, fileManager: fileManager) ?? 0
                        continue
                    case .rename:
                        let renamed = Self.uniqueURL(for: destination, suffix: " copy", fileManager: fileManager)
                        if move {
                            try fileManager.moveItem(at: source, to: renamed)
                        } else {
                            try fileManager.copyItem(at: source, to: renamed)
                        }
                        transferred += Self.allocatedSize(of: renamed, fileManager: fileManager) ?? 0
                        continue
                    }
                }

                do {
                    if move {
                        try fileManager.moveItem(at: source, to: destination)
                    } else {
                        try fileManager.copyItem(at: source, to: destination)
                    }
                } catch let error as NSError {
                    throw Self.mapError(error, url: source)
                }

                transferred += Self.allocatedSize(of: destination, fileManager: fileManager) ?? 0
            }

            progress(
                FileOperationProgress(
                    completedItems: sources.count,
                    totalItems: sources.count,
                    bytesTransferred: transferred,
                    totalBytes: max(totalBytes, transferred),
                    currentFileName: "",
                    isCancelled: false
                )
            )
        }.value
    }

    private func uniqueURL(for url: URL, suffix: String) -> URL {
        Self.uniqueURL(for: url, suffix: suffix, fileManager: .default)
    }

    private static func uniqueURL(for url: URL, suffix: String, fileManager: FileManager) -> URL {
        let directory = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent

        var candidate = directory.appendingPathComponent(base + suffix)
        if !ext.isEmpty {
            candidate = candidate.appendingPathExtension(ext)
        }

        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            var next = directory.appendingPathComponent("\(base)\(suffix) \(counter)")
            if !ext.isEmpty {
                next = next.appendingPathExtension(ext)
            }
            candidate = next
            counter += 1
        }
        return candidate
    }

    private static func allocatedSize(of url: URL, fileManager: FileManager) -> Int64? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }

        if !isDirectory.boolValue {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
            return Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true { continue }
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    private static func makeFileItem(from url: URL) -> FileItem? {
        guard let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isHiddenKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]) else { return nil }

        let isDirectory = values.isDirectory ?? false
        let isSymlink = values.isSymbolicLink ?? false
        let size = Int64(values.fileSize ?? 0)
        let modified = values.contentModificationDate
        let name = url.lastPathComponent

        let displaySize: String
        if isDirectory {
            displaySize = "—"
        } else {
            displaySize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }

        let displayDate: String
        if let modified {
            displayDate = modified.formatted(date: .numeric, time: .shortened)
        } else {
            displayDate = "—"
        }

        return FileItem(
            id: url,
            url: url,
            name: name,
            isDirectory: isDirectory,
            isSymbolicLink: isSymlink,
            isHidden: values.isHidden ?? name.hasPrefix("."),
            size: size,
            modificationDate: modified,
            creationDate: nil,
            permissions: nil,
            contentType: nil,
            displaySize: displaySize,
            displayDate: displayDate,
            displayType: FileItem.makeDisplayType(isDirectory: isDirectory, pathExtension: url.pathExtension)
        )
    }

    private static func mapError(_ error: NSError, url: URL) -> FileOperationError {
        switch error.code {
        case NSFileWriteOutOfSpaceError:
            return .diskFull
        case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
            return .permissionDenied(url)
        case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
            return .sourceMissing(url)
        default:
            return .underlying(error.localizedDescription)
        }
    }
}
