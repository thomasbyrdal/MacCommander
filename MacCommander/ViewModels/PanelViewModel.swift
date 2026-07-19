//
//  PanelViewModel.swift
//  MacCommander
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class PanelViewModel {
    let side: PaneSide

    private(set) var currentURL: URL
    private(set) var items: [FileItem] = []
    /// Cached sorted view of `items`. Never sort inside SwiftUI body / per-row.
    private(set) var displayedItems: [FileItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var freeSpace: Int64?

    var sortConfiguration: SortConfiguration
    var focusedIndex: Int = 0
    var selectedIDs: Set<URL> = []
    var quickSearchQuery: String = ""
    var pathFieldText: String = ""

    private(set) var backStack: [URL] = []
    private(set) var forwardStack: [URL] = []

    private(set) var tabs: [PanelTab]
    private(set) var activeTabID: UUID
    /// Bumped after same-folder reloads so the list can restore scroll without resetting focus to the top.
    private(set) var focusScrollToken: UInt = 0

    private let fileService: FileServiceProtocol
    private let watcher = FileWatcher()
    private var loadTask: Task<Void, Never>?
    private var reloadDebounceTask: Task<Void, Never>?
    private var watcherResumeTask: Task<Void, Never>?
    private var freeSpaceTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var showHiddenFiles: Bool

    init(
        side: PaneSide,
        initialURL: URL,
        sortConfiguration: SortConfiguration,
        showHiddenFiles: Bool,
        fileService: FileServiceProtocol
    ) {
        self.side = side
        self.currentURL = initialURL
        self.sortConfiguration = sortConfiguration
        self.showHiddenFiles = showHiddenFiles
        self.fileService = fileService
        self.pathFieldText = PathFormatter.displayPath(for: initialURL)

        let initialTab = PanelTab(url: initialURL)
        self.tabs = [initialTab]
        self.activeTabID = initialTab.id

        watcher.onChange = { [weak self] in
            Task { @MainActor in
                self?.scheduleReload()
            }
        }
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    var focusedItemID: URL? {
        guard displayedItems.indices.contains(focusedIndex) else { return nil }
        return displayedItems[focusedIndex].id
    }

    var focusedItem: FileItem? {
        guard displayedItems.indices.contains(focusedIndex) else { return nil }
        return displayedItems[focusedIndex]
    }

    var selectedItems: [FileItem] {
        guard !selectedIDs.isEmpty else { return [] }
        return displayedItems.filter { selectedIDs.contains($0.id) && !$0.isParentEntry }
    }

    var effectiveSelection: [FileItem] {
        let explicit = selectedItems
        if !explicit.isEmpty { return explicit }
        if let focused = focusedItem, !focused.isParentEntry {
            return [focused]
        }
        return []
    }

    var fileCount: Int {
        max(items.count - (items.first?.isParentEntry == true ? 1 : 0), 0)
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + ($1.isDirectory ? 0 : $1.size) }
    }

    func updateShowHiddenFiles(_ value: Bool) {
        guard showHiddenFiles != value else { return }
        showHiddenFiles = value
        Task { await reload() }
    }

    func loadInitial() async {
        await navigate(to: currentURL, recordHistory: false)
    }

    func reload() async {
        await loadDirectory(at: currentURL, preserveFocus: true)
    }

    func navigate(to url: URL, recordHistory: Bool = true) async {
        let standardized = url.standardizedFileURL
        if recordHistory, currentURL.standardizedFileURL != standardized {
            backStack.append(currentURL)
            forwardStack.removeAll()
        }

        // Update path immediately so UI feels responsive while listing runs.
        currentURL = standardized
        pathFieldText = PathFormatter.displayPath(for: standardized)
        syncActiveTabURL(standardized)

        await loadDirectory(at: standardized, preserveFocus: false)
    }

    func goUp() async {
        let parent = currentURL.deletingLastPathComponent()
        guard parent.path != currentURL.path else { return }
        await navigate(to: parent)
    }

    func goBack() async {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentURL)
        currentURL = previous
        pathFieldText = PathFormatter.displayPath(for: previous)
        syncActiveTabURL(previous)
        await loadDirectory(at: previous, preserveFocus: false)
    }

    func goForward() async {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentURL)
        currentURL = next
        pathFieldText = PathFormatter.displayPath(for: next)
        syncActiveTabURL(next)
        await loadDirectory(at: next, preserveFocus: false)
    }

    func openFocused() async {
        guard let item = focusedItem else { return }
        if item.isDirectory {
            await navigate(to: item.url)
        } else {
            openInDefaultApp(item.url)
        }
    }

    func openInDefaultApp(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func moveFocus(by delta: Int) {
        guard !displayedItems.isEmpty else { return }
        focusedIndex = min(max(focusedIndex + delta, 0), displayedItems.count - 1)
        quickSearchQuery = ""
    }

    func moveFocusToStart() {
        focusedIndex = 0
        quickSearchQuery = ""
    }

    func moveFocusToEnd() {
        focusedIndex = max(displayedItems.count - 1, 0)
        quickSearchQuery = ""
    }

    func focus(itemID: URL) {
        if let index = displayedItems.firstIndex(where: { $0.id == itemID }) {
            focusedIndex = index
        }
    }

    func toggleSelectionOnFocused() {
        guard let item = focusedItem, !item.isParentEntry else { return }
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func toggleSelectionAndMoveDown() {
        toggleSelectionOnFocused()
        moveFocus(by: 1)
    }

    func selectRange(to itemID: URL) {
        guard let targetIndex = displayedItems.firstIndex(where: { $0.id == itemID }) else { return }
        let start = min(focusedIndex, targetIndex)
        let end = max(focusedIndex, targetIndex)
        for index in start...end {
            let item = displayedItems[index]
            if !item.isParentEntry {
                selectedIDs.insert(item.id)
            }
        }
        focusedIndex = targetIndex
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func setSort(column: SortColumn) {
        if sortConfiguration.column == column {
            sortConfiguration.order = sortConfiguration.order.opposite
        } else {
            sortConfiguration.column = column
            sortConfiguration.order = .ascending
        }
        Task { await rebuildDisplayedItems(preservingFocus: true) }
    }

    func appendQuickSearch(_ character: Character) {
        quickSearchQuery.append(character)
        let query = quickSearchQuery.lowercased()
        if let index = displayedItems.firstIndex(where: {
            !$0.isParentEntry && $0.name.lowercased().hasPrefix(query)
        }) {
            focusedIndex = index
        }
    }

    func clearQuickSearch() {
        quickSearchQuery = ""
    }

    func submitPathField() async {
        let url = PathFormatter.resolve(pathFieldText)
        await navigate(to: url)
    }

    // MARK: - Tabs

    func openNewTab(url: URL? = nil) async {
        persistActiveTabState()
        let tabURL = url ?? currentURL
        let tab = PanelTab(url: tabURL)
        tabs.append(tab)
        activeTabID = tab.id
        backStack = []
        forwardStack = []
        await navigate(to: tabURL, recordHistory: false)
    }

    func closeActiveTab() async {
        guard tabs.count > 1,
              let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }

        tabs.remove(at: index)
        let nextIndex = min(index, tabs.count - 1)
        activeTabID = tabs[nextIndex].id
        await restoreTab(tabs[nextIndex])
    }

    func closeTab(id: UUID) async {
        guard tabs.count > 1,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let wasActive = activeTabID == id
        tabs.remove(at: index)
        if wasActive {
            let nextIndex = min(index, tabs.count - 1)
            activeTabID = tabs[nextIndex].id
            await restoreTab(tabs[nextIndex])
        }
    }

    func selectTab(id: UUID) async {
        guard id != activeTabID,
              let tab = tabs.first(where: { $0.id == id }) else { return }
        persistActiveTabState()
        activeTabID = id
        await restoreTab(tab)
    }

    func selectNextTab() async {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let next = tabs[(index + 1) % tabs.count]
        await selectTab(id: next.id)
    }

    func selectPreviousTab() async {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let previous = tabs[(index - 1 + tabs.count) % tabs.count]
        await selectTab(id: previous.id)
    }

    // MARK: - Private

    private func persistActiveTabState() {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        tabs[index].url = currentURL
        tabs[index].backStack = backStack
        tabs[index].forwardStack = forwardStack
    }

    private func syncActiveTabURL(_ url: URL) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        tabs[index].url = url
        tabs[index].backStack = backStack
        tabs[index].forwardStack = forwardStack
    }

    private func restoreTab(_ tab: PanelTab) async {
        backStack = tab.backStack
        forwardStack = tab.forwardStack
        currentURL = tab.url
        pathFieldText = PathFormatter.displayPath(for: tab.url)
        await loadDirectory(at: tab.url, preserveFocus: false)
    }

    private func loadDirectory(at url: URL, preserveFocus: Bool) async {
        loadTask?.cancel()
        reloadDebounceTask?.cancel()
        watcherResumeTask?.cancel()
        freeSpaceTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        watcher.suspendEvents()

        let previousFocusedID = preserveFocus ? focusedItemID : nil
        let previousFocusedIndex = focusedIndex
        let previousSelectedIDs = preserveFocus ? selectedIDs : []

        let showHidden = showHiddenFiles
        let sort = sortConfiguration
        let service = fileService

        let task = Task {
            do {
                // Validate + list + sort entirely off the main actor.
                let prepared = try await Task.detached(priority: .userInitiated) { () -> (items: [FileItem], displayed: [FileItem]) in
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                          isDirectory.boolValue else {
                        throw FileOperationError.invalidPath(url.path)
                    }
                    let listed = try await service.listDirectory(at: url, showHidden: showHidden)
                    let displayed = sort.sorted(listed)
                    return (listed, displayed)
                }.value

                guard !Task.isCancelled, generation == loadGeneration else { return }

                items = prepared.items
                displayedItems = prepared.displayed
                quickSearchQuery = ""

                if preserveFocus {
                    // Keep selection for items that still exist; drop removed ones (e.g. after move).
                    let remainingIDs = Set(prepared.displayed.map(\.id))
                    selectedIDs = previousSelectedIDs.intersection(remainingIDs)

                    if let previousFocusedID,
                       let index = prepared.displayed.firstIndex(where: { $0.id == previousFocusedID }) {
                        focusedIndex = index
                    } else if !prepared.displayed.isEmpty {
                        // Moved/deleted item — stay on the same row slot.
                        focusedIndex = min(previousFocusedIndex, prepared.displayed.count - 1)
                    } else {
                        focusedIndex = 0
                    }
                    focusScrollToken &+= 1
                } else {
                    selectedIDs.removeAll()
                    focusedIndex = prepared.displayed.isEmpty
                        ? 0
                        : (prepared.displayed.first?.isParentEntry == true && prepared.displayed.count > 1 ? 1 : 0)
                }

                syncActiveTabURL(url)
                watcher.watch(url: url)
                isLoading = false

                // Free space is secondary — don't block navigation.
                freeSpaceTask = Task {
                    let space = await Task.detached(priority: .utility) {
                        service.freeDiskSpace(at: url)
                    }.value
                    guard generation == loadGeneration else { return }
                    freeSpace = space
                }

                // Resume watcher after a short quiet period (not awaited by navigation).
                watcherResumeTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled, generation == loadGeneration else { return }
                    watcher.resumeEvents()
                }
            } catch is CancellationError {
                // Newer navigation superseded this load.
            } catch {
                if generation == loadGeneration {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    watcher.resumeEvents()
                }
            }
        }
        loadTask = task
        await task.value
    }

    private func rebuildDisplayedItems(preservingFocus: Bool) async {
        let focusedID = preservingFocus ? focusedItemID : nil
        let source = items
        let sort = sortConfiguration
        let displayed = await Task.detached(priority: .userInitiated) {
            sort.sorted(source)
        }.value
        displayedItems = displayed
        if let focusedID, let index = displayed.firstIndex(where: { $0.id == focusedID }) {
            focusedIndex = index
        } else {
            focusedIndex = min(focusedIndex, max(displayed.count - 1, 0))
        }
    }

    private func scheduleReload() {
        guard !isLoading else { return }
        reloadDebounceTask?.cancel()
        reloadDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, !isLoading else { return }
            await reload()
        }
    }
}
