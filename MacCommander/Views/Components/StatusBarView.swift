//
//  StatusBarView.swift
//  MacCommander
//

import SwiftUI

struct StatusBarView: View {
    let leftPanel: PanelViewModel
    let rightPanel: PanelViewModel
    let activeSide: PaneSide
    var gitStatus: GitRepoStatus?

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            panelStatus(leftPanel, label: "Left", isActive: activeSide == .left)
            Divider().frame(height: 14)
            panelStatus(rightPanel, label: "Right", isActive: activeSide == .right)
            Spacer()
            if let gitStatus {
                Label(gitStatus.branch, systemImage: "arrow.triangle.branch")
                    .foregroundStyle(theme.secondaryText)
                Text("· \(gitStatus.statuses.count) changed")
                    .foregroundStyle(theme.secondaryText)
            }
            if let free = (activeSide == .left ? leftPanel : rightPanel).freeSpace {
                Text("Free: \(Formatters.byteCountString(free))")
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .font(.caption)
        .foregroundStyle(theme.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            if theme.isClassic {
                theme.chromeBackground
            } else {
                Rectangle().fill(.bar)
            }
        }
    }

    @ViewBuilder
    private func panelStatus(_ panel: PanelViewModel, label: String, isActive: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? theme.accentBorder : theme.secondaryText.opacity(0.35))
                .frame(width: 6, height: 6)
            Text("\(label): \(panel.fileCount) files")
            if !panel.selectedItems.isEmpty {
                Text("· \(panel.selectedItems.count) selected")
                if panel.selectedSize > 0 {
                    Text("· \(Formatters.byteCountString(panel.selectedSize))")
                }
            }
        }
    }
}
