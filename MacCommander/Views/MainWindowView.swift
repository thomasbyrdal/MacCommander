//
//  MainWindowView.swift
//  MacCommander
//

import AppKit
import SwiftUI

struct MainWindowView: View {
    @Bindable var app: AppViewModel

    var body: some View {
        mainContent
            .navigationTitle("MacCommander")
            .toolbar { toolbarContent }
            .searchable(text: $app.searchQuery, isPresented: $app.showSearch, prompt: "Filter files")
            .preferredColorScheme(app.settings.appearance.colorScheme)
            .task { await app.bootstrap() }
            .modifier(MenuNotificationModifier(app: app))
            .modifier(AdvancedMenuNotificationModifier(app: app))
            .modifier(SheetPresentationModifier(app: app))
            .modifier(AdvancedSheetPresentationModifier(app: app))
            .onChange(of: app.settings.showHiddenFiles) { _, newValue in
                app.leftPanel.updateShowHiddenFiles(newValue)
                app.rightPanel.updateShowHiddenFiles(newValue)
            }
            .onChange(of: app.activePanel.currentURL) { _, _ in
                app.refreshGitStatus()
                app.syncTerminalToActivePanel()
            }
            .onChange(of: app.activeSide) { _, _ in
                app.refreshGitStatus()
                app.syncTerminalToActivePanel()
            }
    }

    private var mainContent: some View {
        NavigationSplitView {
            FavoritesSidebarView(app: app)
        } detail: {
            VStack(spacing: 0) {
                DualPaneView(app: app)
                    .padding(8)

                if app.showTerminal {
                    Divider()
                    TerminalPanelView(
                        session: app.terminal,
                        activeDirectory: app.activePanel.currentURL,
                        onClose: { app.showTerminal = false },
                        onOpenExternal: { app.openExternalTerminal() }
                    )
                    .frame(minHeight: 180, idealHeight: 220, maxHeight: 320)
                } else if app.showPreviewPane {
                    Divider()
                    BottomPreviewPanelView(
                        item: app.bottomPreviewItem,
                        previewOverride: { app.plugins.previewOverride(for: $0) },
                        onClose: { app.showPreviewPane = false },
                        onQuickLook: { app.quickLookFocused() }
                    )
                    .frame(minHeight: 180, idealHeight: 220, maxHeight: 320)
                }

                StatusBarView(
                    leftPanel: app.leftPanel,
                    rightPanel: app.rightPanel,
                    activeSide: app.activeSide,
                    gitStatus: app.gitStatus
                )

                FunctionKeyBarView(
                    onView: { app.previewFocused() },
                    onEdit: { app.editFocused() },
                    onCopy: { app.copyToOtherPanel() },
                    onMove: { app.moveToOtherPanel() },
                    onNewFolder: { app.presentNewFolder() },
                    onDelete: { app.deleteSelection() },
                    onMenu: { app.showSettings = true },
                    onQuit: { NSApp.terminate(nil) }
                )
            }
            .background {
                KeyboardMonitor { event in
                    KeyboardCommandRouter.handle(event, app: app)
                }
                .frame(width: 0, height: 0)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                Task { await app.activePanel.goBack() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!app.activePanel.canGoBack)
            .help("Back")

            Button {
                Task { await app.activePanel.goForward() }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!app.activePanel.canGoForward)
            .help("Forward")

            Button {
                Task { await app.activePanel.goUp() }
            } label: {
                Image(systemName: "chevron.up")
            }
            .help("Parent Folder")
        }

        ToolbarItemGroup {
            Button {
                Task { await app.refreshActive() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")

            Button {
                Task { await app.goHome() }
            } label: {
                Image(systemName: "house")
            }
            .help("Home")

            Button {
                app.bookmarkCurrentFolder()
            } label: {
                Image(systemName: "bookmark")
            }
            .help("Bookmark Current Folder")

            Button {
                Task { await app.comparePanels() }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .help("Compare Panels")

            Button {
                Task { await app.scanDuplicates() }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Find Duplicates")

            Button {
                app.toggleTerminal()
            } label: {
                Image(systemName: "terminal")
            }
            .help("Toggle Terminal")
            .symbolVariant(app.showTerminal ? .fill : .none)

            Button {
                app.togglePreviewPane()
            } label: {
                Image(systemName: "eye")
            }
            .help("Toggle Preview")
            .symbolVariant(app.showPreviewPane ? .fill : .none)

            Button {
                Task { await app.openNewTab() }
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle")
            }
            .help("New Tab")

            Button {
                app.showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
        }
    }
}

private struct MenuNotificationModifier: ViewModifier {
    @Bindable var app: AppViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderNewFolder)) { _ in
                app.presentNewFolder()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderNewFile)) { _ in
                app.presentNewFile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderGoUp)) { _ in
                Task { await app.activePanel.goUp() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderGoHome)) { _ in
                Task { await app.goHome() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderGoDesktop)) { _ in
                Task { await app.goDesktop() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderCopy)) { _ in
                app.copyToOtherPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderMove)) { _ in
                app.moveToOtherPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderDelete)) { _ in
                app.deleteSelection()
            }
    }
}

private struct AdvancedMenuNotificationModifier: ViewModifier {
    @Bindable var app: AppViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderClipboardCopy)) { _ in
                app.copyToClipboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderClipboardCut)) { _ in
                app.cutToClipboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderClipboardPaste)) { _ in
                Task { await app.pasteFromClipboard() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderRefresh)) { _ in
                Task { await app.refreshActive() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderBatchRename)) { _ in
                app.presentBatchRename()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderCompare)) { _ in
                Task { await app.comparePanels() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderQuickLook)) { _ in
                app.quickLookFocused()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderNewTab)) { _ in
                Task { await app.openNewTab() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderCloseTab)) { _ in
                Task { await app.closeActiveTab() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderToggleTerminal)) { _ in
                app.toggleTerminal()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderTogglePreview)) { _ in
                app.togglePreviewPane()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderFindDuplicates)) { _ in
                Task { await app.scanDuplicates() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macCommanderHexEditor)) { _ in
                app.openHexEditor()
            }
    }
}

private struct SheetPresentationModifier: ViewModifier {
    @Bindable var app: AppViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: copyMoveBinding) {
                CopyMoveDialog(app: app)
            }
            .sheet(isPresented: deleteBinding) {
                DeleteConfirmDialog(app: app)
            }
            .sheet(isPresented: newFolderBinding) {
                NewFolderDialog(app: app)
            }
            .sheet(isPresented: newFileBinding) {
                NewFileDialog(app: app)
            }
            .sheet(item: renameBinding) { _ in
                RenameDialog(app: app)
            }
            .sheet(isPresented: $app.showSettings) {
                SettingsView(settings: app.settings)
            }
    }

    private var copyMoveBinding: Binding<Bool> {
        Binding(
            get: { app.operations.showCopyMoveSheet },
            set: { app.operations.showCopyMoveSheet = $0 }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { app.operations.showDeleteConfirmation },
            set: { app.operations.showDeleteConfirmation = $0 }
        )
    }

    private var newFolderBinding: Binding<Bool> {
        Binding(
            get: { app.operations.showNewFolderSheet },
            set: { app.operations.showNewFolderSheet = $0 }
        )
    }

    private var newFileBinding: Binding<Bool> {
        Binding(
            get: { app.operations.showNewFileSheet },
            set: { app.operations.showNewFileSheet = $0 }
        )
    }

    private var renameBinding: Binding<FileItem?> {
        Binding(
            get: { app.operations.renameTarget },
            set: { app.operations.renameTarget = $0 }
        )
    }
}

private struct AdvancedSheetPresentationModifier: ViewModifier {
    @Bindable var app: AppViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: batchRenameBinding) {
                BatchRenameDialog(app: app)
            }
            .sheet(item: $app.previewItem) { item in
                FilePreviewView(
                    item: item,
                    pluginOverride: app.plugins.previewOverride(for: item),
                    onClose: { app.previewItem = nil },
                    onQuickLook: {
                        app.previewItem = nil
                        app.quickLookFocused()
                    }
                )
            }
            .sheet(item: $app.editItem) { item in
                TextEditorView(item: item) { app.editItem = nil }
            }
            .sheet(item: $app.hexItem) { item in
                HexEditorView(item: item) { app.hexItem = nil }
            }
            .sheet(isPresented: compareBinding) {
                CompareDialog(app: app)
            }
            .sheet(isPresented: $app.showDuplicateFinder) {
                DuplicateFinderDialog(app: app)
            }
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { app.operations.errorMessage = nil }
            } message: {
                Text(app.operations.errorMessage ?? "")
            }
            .alert("MacCommander", isPresented: infoAlertBinding) {
                Button("OK", role: .cancel) { app.alertMessage = nil }
            } message: {
                Text(app.alertMessage ?? "")
            }
    }

    private var batchRenameBinding: Binding<Bool> {
        Binding(
            get: { app.operations.showBatchRenameSheet },
            set: { app.operations.showBatchRenameSheet = $0 }
        )
    }

    private var compareBinding: Binding<Bool> {
        Binding(
            get: { app.showCompareSheet },
            set: {
                app.showCompareSheet = $0
                if !$0 { app.compareResult = nil }
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: {
                app.operations.errorMessage != nil
                    && !app.operations.showCopyMoveSheet
                    && !app.operations.showDeleteConfirmation
                    && !app.operations.showBatchRenameSheet
            },
            set: { if !$0 { app.operations.errorMessage = nil } }
        )
    }

    private var infoAlertBinding: Binding<Bool> {
        Binding(
            get: { app.alertMessage != nil },
            set: { if !$0 { app.alertMessage = nil } }
        )
    }
}
