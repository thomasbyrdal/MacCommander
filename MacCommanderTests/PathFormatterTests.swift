//
//  PathFormatterTests.swift
//  MacCommanderTests
//

import Foundation
import Testing
@testable import MacCommander

struct PathFormatterTests {
    @Test func tildeForHomeDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(PathFormatter.displayPath(for: home) == "~")
    }

    @Test func tildePrefixForHomeSubpath() {
        let docs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        #expect(PathFormatter.displayPath(for: docs) == "~/Documents")
    }

    @Test func resolveTildePath() {
        let resolved = PathFormatter.resolve("~/Documents")
        let expected = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        #expect(resolved.standardizedFileURL == expected.standardizedFileURL)
    }
}
