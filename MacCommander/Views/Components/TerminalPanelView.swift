//
//  TerminalPanelView.swift
//  MacCommander
//

import AppKit
import SwiftUI

struct TerminalPanelView: View {
    @Bindable var session: TerminalSession
    let activeDirectory: URL
    let onClose: () -> Void
    let onOpenExternal: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(theme.secondaryText)
                Text("Terminal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.columnHeader)
                Text(PathFormatter.displayPath(for: session.currentDirectory))
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)

                Spacer()

                Button("cd Active") {
                    session.changeDirectory(to: activeDirectory)
                }
                .font(.caption)

                Button("Clear") { session.clear() }
                    .font(.caption)

                Button("⌃C") { session.sendInterrupt() }
                    .font(.caption)

                Button("External") { onOpenExternal() }
                    .font(.caption)

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .font(.caption)
                .help("Hide Terminal")
            }
            .foregroundStyle(theme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if theme.isClassic {
                    theme.chromeBackground
                } else {
                    Rectangle().fill(.bar)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(session.output.isEmpty ? " " : session.output)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.previewText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                        .id("terminal-bottom")
                }
                .background(theme.panelBackground)
                .onChange(of: session.output) { _, _ in
                    DispatchQueue.main.async {
                        proxy.scrollTo("terminal-bottom", anchor: .bottom)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("$")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.secondaryText)
                TextField("Command", text: $session.inputBuffer)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.previewText)
                    .onSubmit { session.sendLine() }
                    .disabled(!session.isRunning || session.isBusy)

                Button("Send") { session.sendLine() }
                    .disabled(!session.isRunning || session.isBusy || session.inputBuffer.isEmpty)
            }
            .padding(8)
            .background(theme.columnHeaderFill)
        }
        .frame(minHeight: 160)
        .onAppear {
            if !session.isRunning {
                session.start()
            }
        }
    }
}
