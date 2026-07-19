//
//  QuickLookPresenter.swift
//  MacCommander
//

import AppKit
import Quartz

/// Presents the system Quick Look panel for one or more file URLs.
nonisolated final class QuickLookPresenter: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate, @unchecked Sendable {
    static let shared = QuickLookPresenter()

    private let lock = NSLock()
    private var urls: [URL] = []
    private var currentIndex: Int = 0

    func preview(urls: [URL], startingAt index: Int = 0) {
        guard !urls.isEmpty else { return }
        lock.lock()
        self.urls = urls
        self.currentIndex = min(max(index, 0), urls.count - 1)
        let start = self.currentIndex
        lock.unlock()

        DispatchQueue.main.async {
            guard let panel = QLPreviewPanel.shared() else { return }
            panel.dataSource = self
            panel.delegate = self
            panel.currentPreviewItemIndex = start
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func preview(url: URL) {
        preview(urls: [url], startingAt: 0)
    }

    func close() {
        DispatchQueue.main.async {
            QLPreviewPanel.shared()?.close()
        }
        lock.lock()
        urls = []
        currentIndex = 0
        lock.unlock()
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        lock.lock()
        defer { lock.unlock() }
        guard urls.indices.contains(index) else { return nil }
        return urls[index] as NSURL
    }
}
