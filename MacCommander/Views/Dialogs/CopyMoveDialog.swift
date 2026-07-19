//
//  CopyMoveDialog.swift
//  MacCommander
//

import SwiftUI

struct CopyMoveDialog: View {
    @Bindable var app: AppViewModel

    private var request: FileOperationRequest? { app.operations.activeRequest }
    private var isCopy: Bool { request?.kind == .copy }

    private static let conflictPolicies: [OverwritePolicy] = [.overwrite, .skip, .rename]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isCopy ? "Copy" : "Move")
                .font(.title2.weight(.semibold))

            if let request {
                LabeledContent("Items", value: "\(request.sources.count)")
                LabeledContent("From") {
                    Text(request.sources.first?.deletingLastPathComponent().path ?? "")
                        .font(.caption.monospaced())
                        .lineLimit(2)
                }
                if let destination = request.destination {
                    LabeledContent("To") {
                        Text(destination.path)
                            .font(.caption.monospaced())
                            .lineLimit(2)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("If a file already exists")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Conflict policy", selection: conflictPolicyBinding) {
                        ForEach(Self.conflictPolicies) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            if app.operations.isRunning, let progress = app.operations.progress {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress.fractionCompleted)
                    Text(progress.currentFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(progress.completedItems)/\(progress.totalItems)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if let error = app.operations.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    app.operations.cancelActiveOperation()
                }
                .keyboardShortcut(.cancelAction)

                Button(isCopy ? "Copy" : "Move") {
                    Task { await app.confirmCopyOrMove() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(app.operations.isRunning || request == nil)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            // Dialog already confirms the operation — normalize legacy `.ask` to overwrite.
            if app.operations.activeRequest?.overwritePolicy == .ask {
                setConflictPolicy(.overwrite)
            }
        }
    }

    private var conflictPolicyBinding: Binding<OverwritePolicy> {
        Binding(
            get: {
                let policy = app.operations.activeRequest?.overwritePolicy ?? .overwrite
                return policy == .ask ? .overwrite : policy
            },
            set: { setConflictPolicy($0) }
        )
    }

    private func setConflictPolicy(_ policy: OverwritePolicy) {
        guard var request = app.operations.activeRequest else { return }
        request.overwritePolicy = policy
        app.operations.activeRequest = request
    }
}
