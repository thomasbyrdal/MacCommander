//
//  AppSettings.swift
//  MacCommander
//

import Foundation
import SwiftUI

enum AppearanceMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case system
    case light
    case dark
    case classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .classic: "Classic"
        }
    }

    /// Base SwiftUI color scheme. Classic forces dark so system controls stay readable.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark, .classic: .dark
        }
    }

    var theme: AppTheme {
        switch self {
        case .classic: .classic
        case .system, .light, .dark: .standard
        }
    }
}

enum IconSize: String, CaseIterable, Codable, Sendable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var points: CGFloat {
        switch self {
        case .small: 14
        case .medium: 16
        case .large: 20
        }
    }
}

@Observable
final class AppSettings {
    var appearance: AppearanceMode {
        didSet { persist() }
    }
    var showHiddenFiles: Bool {
        didSet { persist() }
    }
    var defaultStartupFolder: String {
        didSet { persist() }
    }
    var confirmDelete: Bool {
        didSet { persist() }
    }
    var confirmOverwrite: Bool {
        didSet { persist() }
    }
    var confirmMove: Bool {
        didSet { persist() }
    }
    var iconSize: IconSize {
        didSet { persist() }
    }
    var defaultSortColumn: SortColumn {
        didSet { persist() }
    }
    var defaultSortAscending: Bool {
        didSet { persist() }
    }
    var directoriesFirst: Bool {
        didSet { persist() }
    }
    var bookmarks: [Bookmark] {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let storageKey = "MacCommander.AppSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = Self.load(from: defaults)

        appearance = stored?.appearance ?? .system
        showHiddenFiles = stored?.showHiddenFiles ?? false
        defaultStartupFolder = stored?.defaultStartupFolder ?? FileManager.default.homeDirectoryForCurrentUser.path
        confirmDelete = stored?.confirmDelete ?? true
        confirmOverwrite = stored?.confirmOverwrite ?? true
        confirmMove = stored?.confirmMove ?? true
        iconSize = stored?.iconSize ?? .medium
        defaultSortColumn = stored?.defaultSortColumn ?? .name
        defaultSortAscending = stored?.defaultSortAscending ?? true
        directoriesFirst = stored?.directoriesFirst ?? true
        bookmarks = stored?.bookmarks ?? Self.defaultBookmarks()
    }

    var defaultSortConfiguration: SortConfiguration {
        SortConfiguration(
            column: defaultSortColumn,
            order: defaultSortAscending ? .ascending : .descending,
            directoriesFirst: directoriesFirst
        )
    }

    var startupURL: URL {
        URL(fileURLWithPath: defaultStartupFolder, isDirectory: true)
    }

    func addBookmark(_ bookmark: Bookmark) {
        guard !bookmarks.contains(where: { $0.path == bookmark.path }) else { return }
        bookmarks.append(bookmark)
    }

    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
    }

    private func persist() {
        let payload = StoredSettings(
            appearance: appearance,
            showHiddenFiles: showHiddenFiles,
            defaultStartupFolder: defaultStartupFolder,
            confirmDelete: confirmDelete,
            confirmOverwrite: confirmOverwrite,
            confirmMove: confirmMove,
            iconSize: iconSize,
            defaultSortColumn: defaultSortColumn,
            defaultSortAscending: defaultSortAscending,
            directoriesFirst: directoriesFirst,
            bookmarks: bookmarks
        )
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private static func load(from defaults: UserDefaults) -> StoredSettings? {
        guard let data = defaults.data(forKey: "MacCommander.AppSettings") else { return nil }
        return try? JSONDecoder().decode(StoredSettings.self, from: data)
    }

    private static func defaultBookmarks() -> [Bookmark] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            Bookmark(url: home, name: "Home"),
            Bookmark(url: home.appendingPathComponent("Desktop"), name: "Desktop"),
            Bookmark(url: home.appendingPathComponent("Documents"), name: "Documents"),
            Bookmark(url: home.appendingPathComponent("Downloads"), name: "Downloads")
        ]
    }
}

private struct StoredSettings: Codable {
    var appearance: AppearanceMode
    var showHiddenFiles: Bool
    var defaultStartupFolder: String
    var confirmDelete: Bool
    var confirmOverwrite: Bool
    var confirmMove: Bool?
    var iconSize: IconSize
    var defaultSortColumn: SortColumn
    var defaultSortAscending: Bool
    var directoriesFirst: Bool
    var bookmarks: [Bookmark]
}
