//
//  PanelTabBarView.swift
//  MacCommander
//

import SwiftUI

struct PanelTabBarView: View {
    let tabs: [PanelTab]
    let activeTabID: UUID
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNew: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(tabs) { tab in
                        tabButton(tab)
                    }
                }
            }

            Button(action: onNew) {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.text)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("New Tab")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(theme.columnHeaderFill)
    }

    private func tabButton(_ tab: PanelTab) -> some View {
        let isActive = tab.id == activeTabID
        return HStack(spacing: 4) {
            Button {
                onSelect(tab.id)
            } label: {
                Text(tab.title)
                    .font(.caption)
                    .foregroundStyle(isActive ? theme.selectionText : theme.text)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if tabs.count > 1 {
                Button {
                    onClose(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? theme.selectionFill : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isActive ? theme.accentBorder.opacity(0.7) : Color.clear, lineWidth: 1)
        )
    }
}
