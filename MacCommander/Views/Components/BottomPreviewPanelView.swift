//
//  BottomPreviewPanelView.swift
//  MacCommander
//

import AppKit
import SwiftUI

struct BottomPreviewPanelView: View {
    let item: FileItem?
    var previewOverride: ((FileItem) -> AnyView?)? = nil
    let onClose: () -> Void
    let onQuickLook: () -> Void

    /// Debounced selection so arrow-key navigation does not rebuild previews every keypress.
    @State private var displayedItem: FileItem?
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
                Text("Preview")
                    .font(.caption.weight(.semibold))

                if let item = item ?? displayedItem {
                    Text(item.name)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(item.url.path)
                } else {
                    Text("No selection")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button("Quick Look") {
                    onQuickLook()
                }
                .font(.caption)
                .disabled(item == nil || item?.isParentEntry == true)

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .font(.caption)
                .help("Hide Preview")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.bar)

            Group {
                if let item = displayedItem, !item.isParentEntry {
                    FilePreviewContent(
                        item: item,
                        pluginOverride: previewOverride?(item),
                        onQuickLook: onQuickLook
                    )
                    .id(item.id)
                } else {
                    ContentUnavailableView(
                        "Select a file to preview",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Focus a file in the active panel.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minHeight: 160)
        .onAppear {
            displayedItem = item
        }
        .onChange(of: item?.id) { _, _ in
            schedulePreviewUpdate()
        }
        .onDisappear {
            debounceTask?.cancel()
        }
    }

    private func schedulePreviewUpdate() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            displayedItem = item
        }
    }
}
