//
//  FileRowView.swift
//  MacCommander
//

import SwiftUI

struct FileRowView: View {
    let item: FileItem
    let isFocused: Bool
    let isSelected: Bool
    let isActivePanel: Bool
    let iconSize: CGFloat
    var gitStatus: GitFileStatus? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: IconProvider.systemImageName(for: item))
                .font(.system(size: iconSize - 2))
                .foregroundStyle(item.isDirectory ? theme.directoryIcon : theme.secondaryText)
                .frame(width: iconSize + 2, alignment: .center)

            HStack(spacing: 6) {
                Text(item.name)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(nameColor)
                    .help(item.name)

                if let gitStatus, gitStatus != .unknown {
                    Text(gitStatus.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(gitColor(gitStatus))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(gitColor(gitStatus).opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        .help(gitStatus.title)
                }
            }
            .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text(item.isParentEntry ? "" : item.displaySize)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(metaColor)
                .lineLimit(1)
                .frame(width: 72, alignment: .trailing)
                .layoutPriority(0)

            Text(item.isParentEntry ? "" : item.displayDate)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(metaColor)
                .lineLimit(1)
                .frame(width: 140, alignment: .trailing)
                .layoutPriority(0)

            Text(item.isParentEntry ? "" : item.displayType)
                .font(.system(size: 11))
                .foregroundStyle(theme.tertiaryText)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)
                .layoutPriority(0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .contentShape(Rectangle())
    }

    private var nameColor: Color {
        if isFocused && isActivePanel {
            return theme.selectionText
        }
        if item.isParentEntry {
            return theme.secondaryText
        }
        return theme.text
    }

    private var metaColor: Color {
        if isFocused && isActivePanel {
            return theme.selectionText.opacity(0.85)
        }
        return theme.secondaryText
    }

    private var backgroundColor: Color {
        if isFocused && isActivePanel {
            return theme.selectionFill
        }
        if isSelected {
            return theme.inactiveSelectionFill
        }
        return .clear
    }

    private func gitColor(_ status: GitFileStatus) -> Color {
        switch status {
        case .modified, .renamed, .copied: .orange
        case .added: .green
        case .deleted: .red
        case .untracked: theme.isClassic ? Color(red: 0.4, green: 1.0, blue: 1.0) : .blue
        case .conflict: .purple
        case .ignored, .unknown: theme.secondaryText
        }
    }
}
