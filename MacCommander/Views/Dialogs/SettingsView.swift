//
//  SettingsView.swift
//  MacCommander
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Picker("Icon Size", selection: $settings.iconSize) {
                        ForEach(IconSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                }

                Section("Files") {
                    Toggle("Show Hidden Files", isOn: $settings.showHiddenFiles)
                    Toggle("Confirm Delete", isOn: $settings.confirmDelete)
                    Toggle("Confirm Move", isOn: $settings.confirmMove)
                    Toggle("Confirm Overwrite", isOn: $settings.confirmOverwrite)
                    Toggle("Directories First", isOn: $settings.directoriesFirst)
                }

                Section("Defaults") {
                    Picker("Default Sort", selection: $settings.defaultSortColumn) {
                        ForEach(SortColumn.allCases) { column in
                            Text(column.title).tag(column)
                        }
                    }
                    Toggle("Sort Ascending", isOn: $settings.defaultSortAscending)

                    HStack {
                        Text("Startup Folder")
                        Spacer()
                        Text(settings.defaultStartupFolder)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Button("Choose…") {
                            chooseStartupFolder()
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 500)
    }

    private func chooseStartupFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: settings.defaultStartupFolder)
        if panel.runModal() == .OK, let url = panel.url {
            settings.defaultStartupFolder = url.path
        }
    }
}
