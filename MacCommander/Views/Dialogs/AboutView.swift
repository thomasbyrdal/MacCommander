//
//  AboutView.swift
//  MacCommander
//

import AppKit
import SwiftUI

/// Custom About window — the system About panel ignores large icon sizes.
struct AboutView: View {
    private var versionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            if let icon = AppIcon.loadAboutIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 256, height: 256)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }

            Text("MacCommander")
                .font(.title.weight(.semibold))

            Text(versionString)
                .font(.body)
                .foregroundStyle(.secondary)

            Text("A dual-pane file manager for macOS.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Copyright © 2026 byrdal.dk")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("OK") {
                AppIcon.closeAboutPanel()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 360)
        .background(.background)
    }
}
