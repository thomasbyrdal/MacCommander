//
//  AppViewModel.swift
//  MacCommander
//

import AppKit
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum ClipboardMode: Sendable {
    case copy
    case cut
}

struct FileClipboard: Sendable {
    var urls: [URL]
    var mode: ClipboardMode
}

@MainActor
@Observable
final class AppViewModel {
    let settings: AppSettings
    let leftPanel: PanelViewModel
    let rightPanel: PanelViewModel
    let operations: FileOperationViewModel

    var activeSide: PaneSide = .left
    var showSettings = false
    var showSearch = false
    var searchQuery = ""
    var clipboard: FileClipboard?
    var previewItem: FileItem?
    var editItem: FileItem?
    var alertMessage: String?
    var volumes: [VolumeInfo] = []
    var compareResult: CompareResult?
    var isComparing = false
    var showCompareSheet = false
    var showTerminal = false
    var showPreviewPane = false
    var showDuplicateFinder = false
    var duplicateScanResult: DuplicateScanResult?
    var isScanningDuplicates = false
    var duplicateScanProgress = 0
    var hexItem: FileItem?
    var gitStatus: GitRepoStatus?
    /// URLs being dragged from a panel (supports multi-select pane-to-pane moves).
    var draggingURLs: [URL] = []
    let terminal = TerminalSession()
    let plugins = PluginHost()

    private let fileService: FileServiceProtocol
    private let volumeService: VolumeService
    private var gitRefreshTask: Task<Void, Never>?

    init(
        settings: AppSettings = AppSettings(),
        fileService: FileServiceProtocol = FileService(),
        volumeService: VolumeService = VolumeService()
    ) {
        self.settings = settings
        self.fileService = fileService
        self.volumeService = volumeService

        let home = settings.startupURL
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")

        leftPanel = PanelViewModel(
            side: .left,
            initialURL: home,
            sortConfiguration: settings.defaultSortConfiguration,
            showHiddenFiles: settings.showHiddenFiles,
            fileService: fileService
        )

        rightPanel = PanelViewModel(
            side: .right,
            initialURL: FileManager.default.fileExists(atPath: downloads.path) ? downloads : home,
            sortConfiguration: settings.defaultSortConfiguration,
            showHiddenFiles: settings.showHiddenFiles,
            fileService: fileService
        )

        operations = FileOperationViewModel(fileService: fileService)
        plugins.register(ChecksumPlugin())
    }

    var activePanel: PanelViewModel {
        activeSide == .left ? leftPanel : rightPanel
    }

    var inactivePanel: PanelViewModel {
        activeSide == .left ? rightPanel : leftPanel
    }

    func panel(for side: PaneSide) -> PanelViewModel {
        side == .left ? leftPanel : rightPanel
    }

    func bootstrap() async {
        refreshVolumes()
        await leftPanel.loadInitial()
        await rightPanel.loadInitial()
        refreshGitStatus()
    }

    func refreshVolumes() {
        volumes = volumeService.mountedVolumes()
    }

    func switchActivePanel() {
        activeSide = activeSide.opposite
    }

    func activate(_ side: PaneSide) {
        activeSide = side
    }

    func toggleHiddenFiles() {
        settings.showHiddenFiles.toggle()
        leftPanel.updateShowHiddenFiles(settings.showHiddenFiles)
        rightPanel.updateShowHiddenFiles(settings.showHiddenFiles)
    }

    func refreshActive() async {
        await activePanel.reload()
    }

    func refreshBoth() async {
        await leftPanel.reload()
        await rightPanel.reload()
    }

    // MARK: - Navigation shortcuts

    func goHome() async {
        await activePanel.navigate(to: FileManager.default.homeDirectoryForCurrentUser)
    }

    func goDesktop() async {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        await activePanel.navigate(to: desktop)
    }

    // MARK: - File operations

    func copyToOtherPanel() {
        let sources = activePanel.effectiveSelection.map(\.url)
        guard !sources.isEmpty else { return }
        operations.beginCopy(
            sources: sources,
            destination: inactivePanel.currentURL,
            overwritePolicy: settings.confirmOverwrite ? .ask : .overwrite
        )
    }

    func moveToOtherPanel() {
        let sources = activePanel.effectiveSelection.map(\.url)
        guard !sources.isEmpty else { return }
        let destination = inactivePanel.currentURL
        let policy: OverwritePolicy = settings.confirmOverwrite ? .ask : .overwrite
        let needsConfirmation = settings.confirmMove
            || Self.destinationHasNameConflict(sources: sources, destination: destination)

        if needsConfirmation {
            operations.beginMove(
                sources: sources,
                destination: destination,
                overwritePolicy: policy
            )
        } else {
            Task {
                operations.beginMove(
                    sources: sources,
                    destination: destination,
                    overwritePolicy: policy,
                    showConfirmation: false
                )
                await confirmCopyOrMove()
            }
        }
    }

    func deleteSelection(permanent: Bool = false) {
        let sources = activePanel.effectiveSelection.map(\.url)
        guard !sources.isEmpty else { return }
        if settings.confirmDelete {
            operations.beginDelete(sources: sources, permanent: permanent)
        } else {
            Task {
                operations.beginDelete(sources: sources, permanent: permanent)
                await operations.confirmDelete()
                await refreshBoth()
            }
        }
    }

    func renameFocused() {
        guard let item = activePanel.focusedItem, !item.isParentEntry else { return }
        operations.beginRename(item)
    }

    func duplicateSelection() async {
        let items = activePanel.effectiveSelection
        guard !items.isEmpty else { return }
        if await operations.duplicate(items) {
            await activePanel.reload()
        }
    }

    func presentNewFolder() {
        operations.newFolderName = "New Folder"
        operations.showNewFolderSheet = true
    }

    func presentNewFile() {
        operations.newFileName = "untitled.txt"
        operations.showNewFileSheet = true
    }

    func confirmNewFolder() async {
        if await operations.createFolder(in: activePanel.currentURL, name: operations.newFolderName) {
            await activePanel.reload()
        }
    }

    func confirmNewFile() async {
        if await operations.createFile(in: activePanel.currentURL, name: operations.newFileName) {
            await activePanel.reload()
        }
    }

    func confirmRename() async {
        if await operations.confirmRename() {
            await activePanel.reload()
        }
    }

    func confirmCopyOrMove() async {
        await operations.confirmCopyOrMove()
        await refreshBoth()
    }

    func confirmDelete() async {
        await operations.confirmDelete()
        await refreshBoth()
    }

    func compressSelection() async {
        let items = activePanel.effectiveSelection
        guard !items.isEmpty else { return }
        if await operations.compress(items, into: activePanel.currentURL) {
            await activePanel.reload()
        }
    }

    func extractFocused() async {
        guard let item = activePanel.focusedItem,
              item.fileExtension == "zip" else { return }
        if await operations.extract(item, into: activePanel.currentURL) {
            await activePanel.reload()
        }
    }

    func createSymlinkToOtherPanel() async {
        guard let item = activePanel.focusedItem, !item.isParentEntry else { return }
        if await operations.createSymlink(from: item.url, in: inactivePanel.currentURL) {
            await inactivePanel.reload()
        }
    }

    // MARK: - Clipboard

    func copyToClipboard() {
        let urls = activePanel.effectiveSelection.map(\.url)
        guard !urls.isEmpty else { return }
        clipboard = FileClipboard(urls: urls, mode: .copy)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }

    func cutToClipboard() {
        let urls = activePanel.effectiveSelection.map(\.url)
        guard !urls.isEmpty else { return }
        clipboard = FileClipboard(urls: urls, mode: .cut)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }

    func pasteFromClipboard() async {
        guard let clipboard else { return }
        switch clipboard.mode {
        case .copy:
            operations.beginCopy(
                sources: clipboard.urls,
                destination: activePanel.currentURL,
                overwritePolicy: settings.confirmOverwrite ? .ask : .overwrite
            )
            await confirmCopyOrMove()
        case .cut:
            let destination = activePanel.currentURL
            let policy: OverwritePolicy = settings.confirmOverwrite ? .ask : .overwrite
            let needsConfirmation = settings.confirmMove
                || Self.destinationHasNameConflict(sources: clipboard.urls, destination: destination)

            if needsConfirmation {
                operations.beginMove(
                    sources: clipboard.urls,
                    destination: destination,
                    overwritePolicy: policy
                )
            } else {
                operations.beginMove(
                    sources: clipboard.urls,
                    destination: destination,
                    overwritePolicy: policy,
                    showConfirmation: false
                )
                await confirmCopyOrMove()
            }
            self.clipboard = nil
        }
    }

    // MARK: - Preview / Edit

    func previewFocused() {
        guard let item = activePanel.focusedItem, !item.isParentEntry else { return }
        if Self.supportsInAppPreview(item) {
            previewItem = item
        } else {
            quickLookFocused()
        }
    }

    func quickLookFocused() {
        let selection = activePanel.effectiveSelection
        let urls: [URL]
        if selection.isEmpty {
            guard let item = activePanel.focusedItem, !item.isParentEntry else { return }
            urls = [item.url]
        } else {
            urls = selection.map(\.url)
        }
        let startIndex: Int = {
            guard let focused = activePanel.focusedItem else { return 0 }
            return urls.firstIndex(of: focused.url) ?? 0
        }()
        QuickLookPresenter.shared.preview(urls: urls, startingAt: startIndex)
    }

    func presentBatchRename() {
        let urls = activePanel.effectiveSelection.map(\.url)
        guard !urls.isEmpty else { return }
        operations.beginBatchRename(urls: urls)
    }

    func confirmBatchRename() async {
        if await operations.confirmBatchRename() {
            await activePanel.reload()
        }
    }

    func comparePanels() async {
        showCompareSheet = true
        isComparing = true
        defer { isComparing = false }
        do {
            compareResult = try await CompareService.compareDirectories(
                left: leftPanel.currentURL,
                right: rightPanel.currentURL,
                options: CompareOptions(includeHidden: settings.showHiddenFiles)
            )
        } catch {
            operations.errorMessage = error.localizedDescription
        }
    }

    func openNewTab() async {
        await activePanel.openNewTab()
    }

    func closeActiveTab() async {
        await activePanel.closeActiveTab()
    }

    // MARK: - Terminal

    func toggleTerminal() {
        showTerminal.toggle()
        if showTerminal {
            showPreviewPane = false
            if !terminal.isRunning {
                terminal.changeDirectory(to: activePanel.currentURL)
                // Defer start so the panel can mount before the shell spins up.
                Task { @MainActor in
                    self.terminal.start()
                }
            } else {
                terminal.changeDirectory(to: activePanel.currentURL)
            }
        }
    }

    func togglePreviewPane() {
        showPreviewPane.toggle()
        if showPreviewPane {
            showTerminal = false
        }
    }

    /// File shown in the bottom preview pane (follows active panel focus).
    var bottomPreviewItem: FileItem? {
        guard let item = activePanel.focusedItem, !item.isParentEntry else { return nil }
        return item
    }

    func syncTerminalToActivePanel() {
        guard showTerminal else { return }
        terminal.changeDirectory(to: activePanel.currentURL)
    }

    func openExternalTerminal() {
        let dir = activePanel.currentURL.path
        let script = """
        tell application "Terminal"
            do script "cd \(shellEscape(dir))"
            activate
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private func shellEscape(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Duplicates

    func scanDuplicates() async {
        showDuplicateFinder = true
        isScanningDuplicates = true
        duplicateScanProgress = 0
        defer { isScanningDuplicates = false }

        do {
            duplicateScanResult = try await DuplicateFinderService.findDuplicates(
                in: activePanel.currentURL,
                options: DuplicateScanOptions(includeHidden: settings.showHiddenFiles)
            ) { count in
                Task { @MainActor in
                    self.duplicateScanProgress = count
                }
            }
        } catch {
            operations.errorMessage = error.localizedDescription
        }
    }

    func trashDuplicateSelection(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        do {
            try fileService.trashItems(urls)
            await scanDuplicates()
            await activePanel.reload()
        } catch {
            operations.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Hex / Edit

    func openHexEditor() {
        guard let item = activePanel.focusedItem, !item.isParentEntry, !item.isDirectory else { return }
        hexItem = item
    }

    func editFocused() {
        guard let item = activePanel.focusedItem, !item.isParentEntry, !item.isDirectory else { return }
        if Self.looksLikeText(item) {
            editItem = item
        } else {
            hexItem = item
        }
    }

    private static func looksLikeText(_ item: FileItem) -> Bool {
        if let type = item.contentType {
            if type.conforms(to: .text) || type.conforms(to: .sourceCode) || type.conforms(to: .json) || type.conforms(to: .xml) {
                return true
            }
        }
        let textExtensions: Set<String> = [
            "txt", "md", "swift", "json", "xml", "yml", "yaml", "csv", "log",
            "html", "css", "js", "ts", "py", "rb", "sh", "c", "h", "cpp", "m", "mm"
        ]
        return textExtensions.contains(item.fileExtension)
    }

    // MARK: - Git

    /// Debounced, non-blocking — never await this from navigation UI paths.
    func refreshGitStatus() {
        gitRefreshTask?.cancel()
        let url = activePanel.currentURL
        gitRefreshTask = Task {
            // Coalesce rapid folder clicks; git status can be expensive in large repos.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let status = await GitService.status(forDirectory: url)
            guard !Task.isCancelled else { return }
            gitStatus = status
        }
    }

    func gitStatus(for item: FileItem) -> GitFileStatus? {
        gitStatus?.status(for: item.url)
    }

    private static func supportsInAppPreview(_ item: FileItem) -> Bool {
        if item.isDirectory { return true }
        if let type = item.contentType {
            if type.conforms(to: .image)
                || type.conforms(to: .pdf)
                || type.conforms(to: .text)
                || type.conforms(to: .sourceCode)
                || type.conforms(to: .json)
                || type.conforms(to: .xml)
                || type.conforms(to: .movie)
                || type.conforms(to: .audio)
                || type.conforms(to: .audiovisualContent) {
                return true
            }
        }
        let known: Set<String> = [
            "txt", "md", "swift", "json", "xml", "yml", "yaml", "csv", "log",
            "html", "css", "js", "ts", "py", "pdf",
            "png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic",
            "mp4", "mov", "m4v", "avi", "mkv",
            "mp3", "m4a", "aac", "wav", "aiff", "flac"
        ]
        return known.contains(item.fileExtension)
    }

    // MARK: - Bookmarks

    func bookmarkCurrentFolder() {
        settings.addBookmark(Bookmark(url: activePanel.currentURL))
    }

    func navigateToBookmark(_ bookmark: Bookmark) async {
        await activePanel.navigate(to: bookmark.url)
    }

    func navigateToVolume(_ volume: VolumeInfo) async {
        await activePanel.navigate(to: volume.url)
    }

    // MARK: - Drag & Drop

    func beginDrag(urls: [URL]) {
        draggingURLs = urls.map(\.standardizedFileURL)
    }

    /// Drop onto a pane.
    /// - Pane-to-pane: move (dialog only on name conflict).
    /// - External (e.g. Finder): copy (dialog only on name conflict).
    func handleDrop(urls: [URL], onto side: PaneSide) async {
        let destination = panel(for: side).currentURL.standardizedFileURL

        let dropped = urls.map(\.standardizedFileURL)
        let isInternalDrag = dropped.first.map { draggingURLs.contains($0) } ?? false
        let sources = isInternalDrag ? draggingURLs : dropped
        draggingURLs = []

        let transferSources = sources.filter { source in
            let parent = source.deletingLastPathComponent().standardizedFileURL
            guard parent != destination else { return false }
            guard source != destination else { return false }
            let sourcePath = source.path
            if destination.path.hasPrefix(sourcePath.hasSuffix("/") ? sourcePath : sourcePath + "/") {
                return false
            }
            return true
        }
        guard !transferSources.isEmpty else { return }

        let hasConflict = Self.destinationHasNameConflict(
            sources: transferSources,
            destination: destination
        )

        if isInternalDrag {
            if hasConflict {
                operations.beginMove(
                    sources: transferSources,
                    destination: destination,
                    overwritePolicy: .overwrite,
                    showConfirmation: true
                )
            } else {
                operations.beginMove(
                    sources: transferSources,
                    destination: destination,
                    overwritePolicy: .overwrite,
                    showConfirmation: false
                )
                await confirmCopyOrMove()
            }
        } else if hasConflict {
            operations.beginCopy(
                sources: transferSources,
                destination: destination,
                overwritePolicy: .overwrite
            )
        } else {
            operations.beginCopy(
                sources: transferSources,
                destination: destination,
                overwritePolicy: .overwrite
            )
            await confirmCopyOrMove()
        }
    }

    /// True when any source basename already exists in the destination folder.
    private static func destinationHasNameConflict(sources: [URL], destination: URL) -> Bool {
        let fileManager = FileManager.default
        return sources.contains { source in
            let candidate = destination.appendingPathComponent(source.lastPathComponent)
            return fileManager.fileExists(atPath: candidate.path)
        }
    }

    // MARK: - Search filter

    func filteredItems(in panel: PanelViewModel) -> [FileItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard showSearch, !query.isEmpty else { return panel.displayedItems }
        return panel.displayedItems.filter {
            $0.isParentEntry || $0.name.localizedCaseInsensitiveContains(query)
        }
    }
}
