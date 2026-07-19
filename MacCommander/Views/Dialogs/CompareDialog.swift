//
//  CompareDialog.swift
//  MacCommander
//

import SwiftUI

struct CompareDialog: View {
    @Bindable var app: AppViewModel
    @State private var filter: CompareEntryKind? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Directory Comparison")
                    .font(.title2.weight(.semibold))
                Spacer()
                if app.isComparing {
                    ProgressView().controlSize(.small)
                }
            }

            if let result = app.compareResult {
                Text("Left: \(PathFormatter.displayPath(for: result.leftRoot))")
                    .font(.caption.monospaced())
                Text("Right: \(PathFormatter.displayPath(for: result.rightRoot))")
                    .font(.caption.monospaced())

                HStack(spacing: 12) {
                    summaryChip("Only Left", result.onlyLeftCount, .orange)
                    summaryChip("Only Right", result.onlyRightCount, .blue)
                    summaryChip("Different", result.differCount, .red)
                    summaryChip("Identical", result.identicalCount, .green)
                }

                Picker("Filter", selection: $filter) {
                    Text("All").tag(Optional<CompareEntryKind>.none)
                    ForEach(CompareEntryKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(Optional(kind))
                    }
                }
                .pickerStyle(.segmented)

                Table(filteredEntries(result.entries)) {
                    TableColumn("Status") { entry in
                        Text(entry.kind.title)
                            .foregroundStyle(color(for: entry.kind))
                    }
                    .width(90)
                    TableColumn("Path") { entry in
                        Text(entry.relativePath)
                            .font(.caption.monospaced())
                    }
                    TableColumn("Left Size") { entry in
                        Text(sizeText(entry.leftSize))
                            .font(.caption.monospaced())
                    }
                    .width(80)
                    TableColumn("Right Size") { entry in
                        Text(sizeText(entry.rightSize))
                            .font(.caption.monospaced())
                    }
                    .width(80)
                }
                .frame(minHeight: 280)
            } else {
                ContentUnavailableView(
                    "No Comparison",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("Compare the left and right panel folders.")
                )
            }

            HStack {
                Button("Refresh") {
                    Task { await app.comparePanels() }
                }
                Spacer()
                Button("Close") {
                    app.showCompareSheet = false
                    app.compareResult = nil
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 720, height: 520)
        .task {
            if app.compareResult == nil {
                await app.comparePanels()
            }
        }
    }

    private func filteredEntries(_ entries: [CompareEntry]) -> [CompareEntry] {
        guard let filter else { return entries }
        return entries.filter { $0.kind == filter }
    }

    private func summaryChip(_ title: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)").font(.headline)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func color(for kind: CompareEntryKind) -> Color {
        switch kind {
        case .onlyLeft: .orange
        case .onlyRight: .blue
        case .differ: .red
        case .identical: .green
        }
    }

    private func sizeText(_ size: Int64?) -> String {
        guard let size else { return "—" }
        return Formatters.byteCountString(size)
    }
}
