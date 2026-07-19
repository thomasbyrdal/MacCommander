//
//  DuplicateFinderDialog.swift
//  MacCommander
//

import AppKit
import SwiftUI

struct DuplicateFinderDialog: View {
    @Bindable var app: AppViewModel
    @State private var selectedGroupID: String?
    @State private var selectionToDelete: Set<URL> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Duplicate Finder")
                    .font(.title2.weight(.semibold))
                Spacer()
                if app.isScanningDuplicates {
                    ProgressView().controlSize(.small)
                    if app.duplicateScanProgress > 0 {
                        Text("\(app.duplicateScanProgress) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("Scanning: \(PathFormatter.displayPath(for: app.activePanel.currentURL))")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            if let result = app.duplicateScanResult {
                HStack(spacing: 16) {
                    labeledStat("Groups", "\(result.groups.count)")
                    labeledStat("Duplicates", "\(result.duplicateFileCount)")
                    labeledStat("Wasted", Formatters.byteCountString(result.wastedBytes))
                    labeledStat("Scanned", "\(result.scannedFileCount)")
                }

                HSplitView {
                    List(result.groups, selection: $selectedGroupID) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(group.files.count) files · \(Formatters.byteCountString(group.size))")
                                .font(.caption.weight(.semibold))
                            Text(String(group.checksum.prefix(12)) + "…")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .tag(group.id)
                    }
                    .frame(minWidth: 180)

                    groupDetail(result)
                        .frame(minWidth: 320)
                }
                .frame(minHeight: 280)
            } else if !app.isScanningDuplicates {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "doc.on.doc",
                    description: Text("Scan the active panel folder for duplicate files.")
                )
            }

            if let error = app.operations.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button("Rescan") {
                    Task { await app.scanDuplicates() }
                }
                .disabled(app.isScanningDuplicates)

                Button("Move Selected to Trash", role: .destructive) {
                    Task { await app.trashDuplicateSelection(Array(selectionToDelete)) }
                }
                .disabled(selectionToDelete.isEmpty)

                Spacer()
                Button("Close") {
                    app.showDuplicateFinder = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 720, height: 520)
        .task {
            if app.duplicateScanResult == nil {
                await app.scanDuplicates()
            }
        }
    }

    @ViewBuilder
    private func groupDetail(_ result: DuplicateScanResult) -> some View {
        if let selectedGroupID,
           let group = result.groups.first(where: { $0.id == selectedGroupID }) {
            List(group.files, selection: $selectionToDelete) { file in
                HStack {
                    Text(file.url.path)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                    Spacer()
                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    }
                    .font(.caption)
                }
                .tag(file.url)
            }
        } else {
            ContentUnavailableView("Select a group", systemImage: "sidebar.left")
        }
    }

    private func labeledStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
