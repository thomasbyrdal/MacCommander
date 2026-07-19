//
//  DeleteConfirmDialog.swift
//  MacCommander
//

import SwiftUI

struct DeleteConfirmDialog: View {
    @Bindable var app: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(app.operations.pendingDeletePermanent ? "Delete Permanently" : "Move to Trash")
                .font(.title2.weight(.semibold))

            if let request = app.operations.activeRequest {
                Text("\(request.sources.count) item(s) will be \(app.operations.pendingDeletePermanent ? "permanently deleted" : "moved to Trash").")
                Text(request.sources.prefix(5).map(\.lastPathComponent).joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                if request.sources.count > 5 {
                    Text("…and \(request.sources.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Toggle("Delete permanently (do not use Trash)", isOn: Binding(
                get: { app.operations.pendingDeletePermanent },
                set: {
                    app.operations.pendingDeletePermanent = $0
                    app.operations.activeRequest?.permanentDelete = $0
                }
            ))

            if let error = app.operations.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    app.operations.showDeleteConfirmation = false
                    app.operations.activeRequest = nil
                }
                .keyboardShortcut(.cancelAction)

                Button(app.operations.pendingDeletePermanent ? "Delete" : "Move to Trash", role: .destructive) {
                    Task { await app.confirmDelete() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
