//
//  TextEditorView.swift
//  MacCommander
//

import AppKit
import SwiftUI

struct TextEditorView: View {
    let item: FileItem
    let onClose: () -> Void

    @State private var text: String = ""
    @State private var isDirty = false
    @State private var errorMessage: String?
    @State private var saveAsURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.name + (isDirty ? " •" : ""))
                    .font(.headline)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!isDirty)
                Button("Save As…") { saveAs() }
                Button("Close", action: onClose)
            }
            .padding()

            Divider()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .onChange(of: text) { _, _ in
                    isDirty = true
                }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear(perform: load)
    }

    private func load() {
        do {
            text = try String(contentsOf: item.url, encoding: .utf8)
            isDirty = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            text = ""
        }
    }

    private func save() {
        do {
            try text.write(to: item.url, atomically: true, encoding: .utf8)
            isDirty = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.name
        panel.directoryURL = item.url.deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                isDirty = false
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
