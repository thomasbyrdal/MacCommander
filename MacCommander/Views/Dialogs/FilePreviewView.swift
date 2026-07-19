//
//  FilePreviewView.swift
//  MacCommander
//

import SwiftUI

struct FilePreviewView: View {
    let item: FileItem
    var pluginOverride: AnyView? = nil
    let onClose: () -> Void
    var onQuickLook: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                if onQuickLook != nil {
                    Button("Quick Look") {
                        onQuickLook?()
                    }
                }
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            FilePreviewContent(
                item: item,
                pluginOverride: pluginOverride,
                onQuickLook: onQuickLook
            )
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}
