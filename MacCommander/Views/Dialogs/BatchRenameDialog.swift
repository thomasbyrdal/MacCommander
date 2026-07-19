//
//  BatchRenameDialog.swift
//  MacCommander
//

import SwiftUI

struct BatchRenameDialog: View {
    @Bindable var app: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Batch Rename")
                .font(.title2.weight(.semibold))

            Text("Tokens: {name} {ext} {counter} {date}")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Template", text: Binding(
                    get: { app.operations.batchRenameTemplate },
                    set: {
                        app.operations.batchRenameTemplate = $0
                        app.operations.refreshBatchRenamePlan()
                    }
                ))
                .textFieldStyle(.roundedBorder)

                Stepper(
                    "Start \(app.operations.batchRenameStartIndex)",
                    value: Binding(
                        get: { app.operations.batchRenameStartIndex },
                        set: {
                            app.operations.batchRenameStartIndex = $0
                            app.operations.refreshBatchRenamePlan()
                        }
                    ),
                    in: 0...9999
                )
                .frame(width: 140)
            }

            Toggle("Skip collisions", isOn: Binding(
                get: { app.operations.batchRenameSkipCollisions },
                set: { app.operations.batchRenameSkipCollisions = $0 }
            ))

            if let plan = app.operations.batchRenamePlan {
                Text("\(plan.changedCount) of \(plan.items.count) will rename · \(plan.collisionCount) collisions")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Table(plan.items) {
                    TableColumn("Current") { item in
                        Text(item.source.lastPathComponent)
                            .font(.caption.monospaced())
                    }
                    TableColumn("New Name") { item in
                        Text(item.proposedName)
                            .font(.caption.monospaced())
                            .foregroundStyle(item.hasCollision ? .red : (item.isChanged ? .primary : .secondary))
                    }
                }
                .frame(minHeight: 220)
            }

            if let error = app.operations.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    app.operations.showBatchRenameSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    Task { await app.confirmBatchRename() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(app.operations.isRunning || (app.operations.batchRenamePlan?.changedCount ?? 0) == 0)
            }
        }
        .padding(20)
        .frame(width: 560, height: 420)
    }
}
