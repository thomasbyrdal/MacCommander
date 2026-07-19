//
//  HexEditorView.swift
//  MacCommander
//

import SwiftUI

struct HexEditorView: View {
    @State private var document: HexEditorDocument?
    @State private var loadError: String?
    @State private var selectedOffset: Int = 0
    @State private var editHex: String = ""
    let item: FileItem
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.name + ((document?.isDirty == true) ? " •" : ""))
                    .font(.headline)
                Spacer()
                if let document {
                    Text("\(document.bytes.count) bytes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Save") {
                        do {
                            try document.save()
                        } catch {
                            document.errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(!document.isDirty)
                    .keyboardShortcut("s", modifiers: .command)
                }
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if let loadError {
                ContentUnavailableView("Unable to open", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if let document {
                header
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(0..<document.rowCount, id: \.self) { row in
                            hexRow(document, row: row)
                        }
                    }
                    .padding(8)
                }

                HStack {
                    Text("Offset \(String(format: "%08X", selectedOffset))")
                        .font(.caption.monospaced())
                    TextField("Hex byte", text: $editHex)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .onSubmit { applyEdit(to: document) }
                    Button("Set") { applyEdit(to: document) }
                    Spacer()
                }
                .padding(8)

                if let error = document.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Offset").frame(width: 80, alignment: .leading)
            Text("Hex").frame(maxWidth: .infinity, alignment: .leading)
            Text("ASCII").frame(width: 140, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
    }

    private func hexRow(_ document: HexEditorDocument, row: Int) -> some View {
        let info = document.row(at: row)
        let isSelectedRow = selectedOffset / document.bytesPerRow == row
        return HStack(spacing: 12) {
            Text(String(format: "%08X", info.offset))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(info.hex)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(info.ascii)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.vertical, 1)
        .background(isSelectedRow ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedOffset = info.offset
            if document.bytes.indices.contains(info.offset) {
                editHex = String(format: "%02X", document.bytes[info.offset])
            }
        }
    }

    private func applyEdit(to document: HexEditorDocument) {
        document.setByte(at: selectedOffset, hex: editHex)
        if document.bytes.indices.contains(selectedOffset) {
            editHex = String(format: "%02X", document.bytes[selectedOffset])
        }
    }

    private func load() {
        do {
            let doc = try HexEditorDocument(url: item.url)
            document = doc
            if !doc.bytes.isEmpty {
                editHex = String(format: "%02X", doc.bytes[0])
            }
        } catch {
            loadError = error.localizedDescription
        }
    }
}
