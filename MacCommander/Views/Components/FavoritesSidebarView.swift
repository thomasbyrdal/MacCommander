//
//  FavoritesSidebarView.swift
//  MacCommander
//

import SwiftUI

struct FavoritesSidebarView: View {
    @Bindable var app: AppViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section("Favorites") {
                ForEach(app.settings.bookmarks) { bookmark in
                    Button {
                        Task { await app.navigateToBookmark(bookmark) }
                    } label: {
                        Label(bookmark.name, systemImage: iconName(for: bookmark))
                            .foregroundStyle(theme.text)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.panelBackground)
                    .contextMenu {
                        Button("Remove Bookmark", role: .destructive) {
                            app.settings.removeBookmark(id: bookmark.id)
                        }
                    }
                }
            }

            Section("Volumes") {
                ForEach(app.volumes) { volume in
                    Button {
                        Task { await app.navigateToVolume(volume) }
                    } label: {
                        Label(volume.name, systemImage: volumeIcon(volume))
                            .foregroundStyle(theme.text)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.panelBackground)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .foregroundStyle(theme.text)
        .tint(theme.accentBorder)
        .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)
        .onAppear { app.refreshVolumes() }
    }

    private func iconName(for bookmark: Bookmark) -> String {
        switch bookmark.name {
        case "Home": "house"
        case "Desktop": "desktopcomputer"
        case "Documents": "doc"
        case "Downloads": "arrow.down.circle"
        default: "folder"
        }
    }

    private func volumeIcon(_ volume: VolumeInfo) -> String {
        if volume.isNetwork { return "network" }
        if volume.isRemovable || volume.isEjectable { return "externaldrive" }
        return "internaldrive"
    }
}
