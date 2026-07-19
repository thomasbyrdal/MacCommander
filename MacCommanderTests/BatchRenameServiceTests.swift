//
//  BatchRenameServiceTests.swift
//  MacCommanderTests
//

import Foundation
import Testing
@testable import MacCommander

struct BatchRenameServiceTests {
    @Test func templateReplacesTokens() {
        let urls = [
            URL(fileURLWithPath: "/tmp/photo.jpg"),
            URL(fileURLWithPath: "/tmp/vacation.png")
        ]
        let plan = BatchRenameService.preview(
            urls: urls,
            template: "{name}_{counter}.{ext}",
            startIndex: 1,
            date: Date(timeIntervalSince1970: 0)
        )

        #expect(plan.items.map(\.proposedName) == ["photo_1.jpg", "vacation_2.png"])
        #expect(plan.changedCount == 2)
    }

    @Test func preservesExtensionWhenMissingFromTemplate() {
        let urls = [URL(fileURLWithPath: "/tmp/notes.txt")]
        let plan = BatchRenameService.preview(urls: urls, template: "doc_{counter}", startIndex: 3)
        #expect(plan.items.first?.proposedName == "doc_3.txt")
    }

    @Test func applyRenamesFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BatchRename-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let a = root.appendingPathComponent("a.txt")
        let b = root.appendingPathComponent("b.txt")
        try "a".write(to: a, atomically: true, encoding: .utf8)
        try "b".write(to: b, atomically: true, encoding: .utf8)

        let plan = BatchRenameService.preview(urls: [a, b], template: "file_{counter}.{ext}", startIndex: 1)
        let count = try BatchRenameService.apply(plan, skipCollisions: true)
        #expect(count == 2)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("file_1.txt").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("file_2.txt").path))
    }
}
