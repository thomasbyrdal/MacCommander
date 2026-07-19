//
//  NewItemDialogs.swift
//  MacCommander
//

import SwiftUI

struct NewFolderDialog: View {
    @Bindable var app: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Folder")
                .font(.title2.weight(.semibold))

            TextField("Folder name", text: Binding(
                get: { app.operations.newFolderName },
                set: { app.operations.newFolderName = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            if let error = app.operations.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") { app.operations.showNewFolderSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    Task { await app.confirmNewFolder() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

struct NewFileDialog: View {
    @Bindable var app: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New File")
                .font(.title2.weight(.semibold))

            TextField("File name", text: Binding(
                get: { app.operations.newFileName },
                set: { app.operations.newFileName = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            if let error = app.operations.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") { app.operations.showNewFileSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    Task { await app.confirmNewFile() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
