//
//  MacCommanderTests.swift
//  MacCommanderTests
//

import Foundation
import Testing
@testable import MacCommander

@MainActor
struct MacCommanderTests {
    @Test func appSettingsDefaultBookmarksIncludeHome() {
        let suiteName = "dk.byrdal.MacCommander.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.bookmarks.contains(where: { $0.name == "Home" }))
        #expect(settings.confirmDelete == true)
    }
}
