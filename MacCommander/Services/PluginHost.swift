//
//  PluginHost.swift
//  MacCommander
//

import AppKit
import CryptoKit
import SwiftUI

struct PluginMenuAction: Identifiable {
    let id: String
    let title: String
    var isDestructive: Bool = false
    let run: @MainActor () async -> Void
}

/// Extension point for future plugins (FTP, sync, checksum tools, etc.).
@MainActor
protocol MacCommanderPlugin: AnyObject {
    var id: String { get }
    var name: String { get }

    func contextMenuActions(for items: [FileItem], side: PaneSide, app: AppViewModel) -> [PluginMenuAction]
    func previewProvider(for item: FileItem) -> AnyView?
}

extension MacCommanderPlugin {
    func contextMenuActions(for items: [FileItem], side: PaneSide, app: AppViewModel) -> [PluginMenuAction] {
        []
    }

    func previewProvider(for item: FileItem) -> AnyView? {
        nil
    }
}

@MainActor
@Observable
final class PluginHost {
    private(set) var plugins: [any MacCommanderPlugin] = []

    func register(_ plugin: any MacCommanderPlugin) {
        guard !plugins.contains(where: { $0.id == plugin.id }) else { return }
        plugins.append(plugin)
    }

    func unregister(id: String) {
        plugins.removeAll { $0.id == id }
    }

    func contextActions(for items: [FileItem], side: PaneSide, app: AppViewModel) -> [PluginMenuAction] {
        plugins.flatMap { $0.contextMenuActions(for: items, side: side, app: app) }
    }

    func previewOverride(for item: FileItem) -> AnyView? {
        for plugin in plugins {
            if let view = plugin.previewProvider(for: item) {
                return view
            }
        }
        return nil
    }
}

/// Built-in sample plugin that offers a checksum action — proves the extension point.
@MainActor
final class ChecksumPlugin: MacCommanderPlugin {
    let id = "builtin.checksum"
    let name = "Checksum"

    func contextMenuActions(for items: [FileItem], side: PaneSide, app: AppViewModel) -> [PluginMenuAction] {
        guard let item = items.first, !item.isDirectory, !item.isParentEntry else { return [] }
        return [
            PluginMenuAction(id: "checksum.sha256", title: "Copy SHA-256 Checksum") {
                await Self.copySHA256(of: item.url, into: app)
            }
        ]
    }

    private static func copySHA256(of url: URL, into app: AppViewModel) async {
        do {
            let digest = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                let hash = SHA256.hash(data: data)
                return hash.map { String(format: "%02x", $0) }.joined()
            }.value
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(digest, forType: .string)
            app.alertMessage = "SHA-256 copied:\n\(digest)"
        } catch {
            app.operations.errorMessage = error.localizedDescription
        }
    }
}
