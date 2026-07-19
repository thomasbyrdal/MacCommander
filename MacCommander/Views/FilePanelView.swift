//
//  FilePanelView.swift
//  MacCommander
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FilePanelView: View {
    @Bindable var app: AppViewModel
    let side: PaneSide

    private var panel: PanelViewModel { app.panel(for: side) }
    private var isActive: Bool { app.activeSide == side }

    var body: some View {
        VStack(spacing: 0) {
            PanelTabBarView(
                tabs: panel.tabs,
                activeTabID: panel.activeTabID,
                onSelect: { id in
                    app.activate(side)
                    Task { await panel.selectTab(id: id) }
                },
                onClose: { id in
                    app.activate(side)
                    Task { await panel.closeTab(id: id) }
                },
                onNew: {
                    app.activate(side)
                    Task { await panel.openNewTab() }
                }
            )
            pathHeader
            columnHeader
            fileList
            if let error = panel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isActive ? 2 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            app.activate(side)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private var pathHeader: some View {
        HStack(spacing: 6) {
            TextField(
                "Path",
                text: Binding(
                    get: { panel.pathFieldText },
                    set: { panel.pathFieldText = $0 }
                )
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12, design: .monospaced))
            .onSubmit {
                Task { await panel.submitPathField() }
            }

            if panel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if !panel.quickSearchQuery.isEmpty {
                Text(panel.quickSearchQuery)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
        }
        .padding(8)
        .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            // Icon gutter — must have an explicit height or Color.clear expands vertically.
            Color.clear
                .frame(width: app.settings.iconSize.points + 2, height: 1)

            sortButton("Name", column: .name)
                .frame(maxWidth: .infinity, alignment: .leading)
            sortButton("Size", column: .size)
                .frame(width: 72, alignment: .trailing)
            sortButton("Modified", column: .date)
                .frame(width: 140, alignment: .trailing)
            sortButton("Type", column: .type)
                .frame(width: 80, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.primary.opacity(0.05))
    }

    private func sortButton(_ title: String, column: SortColumn) -> some View {
        Button {
            panel.setSort(column: column)
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if panel.sortConfiguration.column == column {
                    Image(systemName: panel.sortConfiguration.order == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var fileList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(app.filteredItems(in: panel), id: \.id) { item in
                    FileRowView(
                        item: item,
                        isFocused: panel.focusedItemID == item.id,
                        isSelected: panel.selectedIDs.contains(item.id),
                        isActivePanel: isActive,
                        iconSize: app.settings.iconSize.points,
                        gitStatus: isActive ? app.gitStatus(for: item) : nil
                    )
                    .tag(item.id)
                    .id(item.id)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        app.activate(side)
                        panel.focus(itemID: item.id)
                        Task { await panel.openFocused() }
                    }
                    .onTapGesture(count: 1) {
                        app.activate(side)
                        if NSEvent.modifierFlags.contains(.shift) {
                            panel.selectRange(to: item.id)
                        } else if NSEvent.modifierFlags.contains(.command) {
                            if panel.selectedIDs.contains(item.id) {
                                panel.selectedIDs.remove(item.id)
                            } else {
                                panel.selectedIDs.insert(item.id)
                            }
                            panel.focus(itemID: item.id)
                        } else {
                            panel.clearSelection()
                            panel.focus(itemID: item.id)
                        }
                    }
                    .contextMenu {
                        fileContextMenu(for: item)
                    }
                    .onDrag {
                        dragProvider(for: item)
                    } preview: {
                        Label(item.name, systemImage: IconProvider.systemImageName(for: item))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: panel.focusedIndex) { _, _ in
                if let id = panel.focusedItemID {
                    // Minimal scroll — keep the list from jumping when focus moves nearby.
                    proxy.scrollTo(id, anchor: nil)
                }
            }
            .onChange(of: panel.focusScrollToken) { _, _ in
                // After reload (move/delete/etc.), restore visibility without jumping to the top.
                if let id = panel.focusedItemID {
                    proxy.scrollTo(id, anchor: nil)
                }
            }
        }
    }

    @ViewBuilder
    private func fileContextMenu(for item: FileItem) -> some View {
        Button("Open") {
            panel.focus(itemID: item.id)
            Task { await panel.openFocused() }
        }
        Button("Open in New Tab") {
            app.activate(side)
            Task { await panel.openNewTab(url: item.isDirectory ? item.url : panel.currentURL) }
        }
        Button("Reveal in Finder") {
            panel.revealInFinder(item.url)
        }
        Button("Quick Look") {
            panel.focus(itemID: item.id)
            app.quickLookFocused()
        }
        Button("Hex Editor") {
            panel.focus(itemID: item.id)
            app.openHexEditor()
        }
        Divider()
        Button("Rename…") {
            panel.focus(itemID: item.id)
            app.renameFocused()
        }
        Button("Batch Rename…") {
            panel.focus(itemID: item.id)
            if !panel.selectedIDs.contains(item.id) {
                panel.selectedIDs = [item.id]
            }
            app.presentBatchRename()
        }
        Button("Duplicate") {
            panel.focus(itemID: item.id)
            Task { await app.duplicateSelection() }
        }
        Divider()
        Button("Copy to Other Panel") {
            panel.focus(itemID: item.id)
            app.copyToOtherPanel()
        }
        Button("Move to Other Panel") {
            panel.focus(itemID: item.id)
            app.moveToOtherPanel()
        }
        Divider()
        Button("Compress") {
            panel.focus(itemID: item.id)
            Task { await app.compressSelection() }
        }
        if item.fileExtension == "zip" {
            Button("Extract Here") {
                panel.focus(itemID: item.id)
                Task { await app.extractFocused() }
            }
        }
        let pluginActions = app.plugins.contextActions(
            for: panel.effectiveSelection.isEmpty ? [item] : panel.effectiveSelection,
            side: side,
            app: app
        )
        if !pluginActions.isEmpty {
            Divider()
            ForEach(pluginActions) { action in
                Button(action.title, role: action.isDestructive ? .destructive : nil) {
                    Task { await action.run() }
                }
            }
        }
        Divider()
        Button("Get Info") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
        Divider()
        Button("New Folder…") { app.presentNewFolder() }
        Button("New File…") { app.presentNewFile() }
        Divider()
        Button("Delete…", role: .destructive) {
            panel.focus(itemID: item.id)
            app.deleteSelection()
        }
    }

    private func dragProvider(for item: FileItem) -> NSItemProvider {
        app.activate(side)
        guard !item.isParentEntry else {
            return NSItemProvider()
        }

        let urls: [URL]
        if panel.selectedIDs.contains(item.id), panel.selectedIDs.count > 1 {
            urls = panel.selectedItems.map(\.url)
        } else {
            urls = [item.url]
        }
        app.beginDrag(urls: urls)
        return NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            Task { await app.handleDrop(urls: urls, onto: side) }
        }
        return true
    }
}
