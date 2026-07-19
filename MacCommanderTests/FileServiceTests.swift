//
//  FileServiceTests.swift
//  MacCommanderTests
//

import Foundation
import Testing
@testable import MacCommander

struct FileServiceTests {
    @Test func listDirectoryIncludesCreatedFile() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCommanderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let fileURL = temp.appendingPathComponent("hello.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let service = FileService()
        let items = try await service.listDirectory(at: temp, showHidden: false)
        #expect(items.contains(where: { $0.name == "hello.txt" }))
    }

    @Test func createRenameAndTrash() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCommanderOps-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let service = FileService()
        let fileURL = temp.appendingPathComponent("note.txt")
        try service.createEmptyFile(at: fileURL)

        let renamed = try service.renameItem(at: fileURL, to: "renamed.txt")
        #expect(FileManager.default.fileExists(atPath: renamed.path))

        try service.trashItems([renamed])
        #expect(!FileManager.default.fileExists(atPath: renamed.path))
    }

    @Test func copyItemsCreatesDestination() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCommanderCopy-\(UUID().uuidString)", isDirectory: true)
        let sourceDir = root.appendingPathComponent("src", isDirectory: true)
        let destDir = root.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceFile = sourceDir.appendingPathComponent("data.bin")
        try Data("payload".utf8).write(to: sourceFile)

        let service = FileService()
        try await service.copyItems([sourceFile], to: destDir, overwritePolicy: .overwrite) { _ in }

        #expect(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("data.bin").path))
    }
}
