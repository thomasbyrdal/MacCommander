//
//  CompareServiceTests.swift
//  MacCommanderTests
//

import Foundation
import Testing
@testable import MacCommander

struct CompareServiceTests {
    @Test func detectsOnlyLeftRightAndIdentical() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Compare-\(UUID().uuidString)", isDirectory: true)
        let left = root.appendingPathComponent("left", isDirectory: true)
        let right = root.appendingPathComponent("right", isDirectory: true)
        try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "shared".write(to: left.appendingPathComponent("shared.txt"), atomically: true, encoding: .utf8)
        try "shared".write(to: right.appendingPathComponent("shared.txt"), atomically: true, encoding: .utf8)
        try "left-only".write(to: left.appendingPathComponent("onlyL.txt"), atomically: true, encoding: .utf8)
        try "right-only".write(to: right.appendingPathComponent("onlyR.txt"), atomically: true, encoding: .utf8)
        try "A".write(to: left.appendingPathComponent("diff.txt"), atomically: true, encoding: .utf8)
        try "BB".write(to: right.appendingPathComponent("diff.txt"), atomically: true, encoding: .utf8)

        let result = try await CompareService.compareDirectories(left: left, right: right)

        #expect(result.entries.contains(where: { $0.relativePath == "onlyL.txt" && $0.kind == .onlyLeft }))
        #expect(result.entries.contains(where: { $0.relativePath == "onlyR.txt" && $0.kind == .onlyRight }))
        #expect(result.entries.contains(where: { $0.relativePath == "diff.txt" && $0.kind == .differ }))
        #expect(result.entries.contains(where: { $0.relativePath == "shared.txt" && $0.kind == .identical }))
    }
}
