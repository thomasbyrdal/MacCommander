//
//  FunctionKeyBarView.swift
//  MacCommander
//

import SwiftUI

struct FunctionKeyBarView: View {
    let onView: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onMove: () -> Void
    let onNewFolder: () -> Void
    let onDelete: () -> Void
    let onMenu: () -> Void
    let onQuit: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            FunctionKeyButton(key: "F3", title: "View", action: onView)
            FunctionKeyButton(key: "F4", title: "Edit", action: onEdit)
            FunctionKeyButton(key: "F5", title: "Copy", action: onCopy)
            FunctionKeyButton(key: "F6", title: "Move", action: onMove)
            FunctionKeyButton(key: "F7", title: "MkDir", action: onNewFolder)
            FunctionKeyButton(key: "F8", title: "Delete", action: onDelete)
            FunctionKeyButton(key: "F9", title: "Menu", action: onMenu)
            FunctionKeyButton(key: "F10", title: "Quit", action: onQuit)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            if theme.isClassic {
                theme.chromeBackground
            } else {
                Rectangle().fill(.bar)
            }
        }
    }
}

private struct FunctionKeyButton: View {
    let key: String
    let title: String
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(key)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.isClassic ? theme.columnHeader : theme.secondaryText)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(theme.functionKeyFill, in: RoundedRectangle(cornerRadius: 4))
    }
}
