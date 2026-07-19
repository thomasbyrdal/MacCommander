//
//  DuplicateFinderServiceTests.swift
//  MacCommanderTests
//

import Foundation
import Testing
@testable import MacCommander

struct DuplicateFinderServiceTests {
    @Test func findsIdenticalFileContents() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dupes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let payload = Data("duplicate-content".utf8)
        try payload.write(to: root.appendingPathComponent("a.txt"))
        try payload.write(to: root.appendingPathComponent("b.txt"))
        try Data("unique".utf8).write(to: root.appendingPathComponent("c.txt"))

        let result = try await DuplicateFinderService.findDuplicates(in: root)
        #expect(result.groups.count == 1)
        #expect(result.groups[0].files.count == 2)
        #expect(result.wastedBytes > 0)
    }
}
