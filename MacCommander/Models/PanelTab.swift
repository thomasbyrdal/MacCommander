//
//  PanelTab.swift
//  MacCommander
//

import Foundation

/// Lightweight saved state for a folder tab within a panel.
nonisolated struct PanelTab: Identifiable, Hashable, Sendable {
    let id: UUID
    var url: URL
    var backStack: [URL]
    var forwardStack: [URL]

    var title: String {
        if url.path == FileManager.default.homeDirectoryForCurrentUser.path {
            return "Home"
        }
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    init(id: UUID = UUID(), url: URL, backStack: [URL] = [], forwardStack: [URL] = []) {
        self.id = id
        self.url = url
        self.backStack = backStack
        self.forwardStack = forwardStack
    }
}
