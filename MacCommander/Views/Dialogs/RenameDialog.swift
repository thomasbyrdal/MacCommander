//
//  RenameDialog.swift
//  MacCommander
//

import SwiftUI

struct RenameDialog: View {
    @Bindable var app: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename")
                .font(.title2.weight(.semibold))

            TextField("Name", text: Binding(
                get: { app.operations.renameText },
                set: { app.operations.renameText = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            if let error = app.operations.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    app.operations.renameTarget = nil
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    Task { await app.confirmRename() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
