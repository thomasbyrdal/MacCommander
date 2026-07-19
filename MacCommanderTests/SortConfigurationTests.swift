//
//  SortConfigurationTests.swift
//  MacCommanderTests
//

import Foundation
import Testing
@testable import MacCommander

struct SortConfigurationTests {
    @Test func directoriesComeFirstWhenEnabled() {
        let files = [
            makeItem(name: "zebra.txt", isDirectory: false, size: 10),
            makeItem(name: "Alpha", isDirectory: true, size: 0),
            makeItem(name: "beta.txt", isDirectory: false, size: 20)
        ]

        let sorted = SortConfiguration(column: .name, order: .ascending, directoriesFirst: true).sorted(files)
        #expect(sorted.map(\.name) == ["Alpha", "beta.txt", "zebra.txt"])
    }

    @Test func sortBySizeDescending() {
        let files = [
            makeItem(name: "a", isDirectory: false, size: 1),
            makeItem(name: "b", isDirectory: false, size: 100),
            makeItem(name: "c", isDirectory: false, size: 50)
        ]

        let sorted = SortConfiguration(column: .size, order: .descending, directoriesFirst: false).sorted(files)
        #expect(sorted.map(\.name) == ["b", "c", "a"])
    }

    @Test func parentEntryStaysFirst() {
        let parent = FileItem.parentEntry(of: URL(fileURLWithPath: "/tmp/demo"))
        let files = [
            makeItem(name: "z", isDirectory: false, size: 1),
            parent,
            makeItem(name: "a", isDirectory: true, size: 0)
        ]

        let sorted = SortConfiguration(column: .name, order: .ascending, directoriesFirst: true).sorted(files)
        #expect(sorted.first?.isParentEntry == true)
        #expect(sorted.map(\.name) == ["..", "a", "z"])
    }

    private func makeItem(name: String, isDirectory: Bool, size: Int64) -> FileItem {
        FileItem(
            id: URL(fileURLWithPath: "/tmp/\(name)"),
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            isDirectory: isDirectory,
            isSymbolicLink: false,
            isHidden: false,
            size: size,
            modificationDate: nil,
            creationDate: nil,
            permissions: nil,
            contentType: nil,
            displaySize: isDirectory ? "—" : "\(size)",
            displayDate: "—",
            displayType: FileItem.makeDisplayType(isDirectory: isDirectory, pathExtension: (name as NSString).pathExtension)
        )
    }
}
