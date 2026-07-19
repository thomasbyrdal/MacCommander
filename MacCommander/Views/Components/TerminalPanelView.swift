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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                Text("Terminal")
                    .font(.caption.weight(.semibold))
                Text(PathFormatter.displayPath(for: session.currentDirectory))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.bar)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(session.output.isEmpty ? " " : session.output)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                        .id("terminal-bottom")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: session.output) { _, _ in
                    DispatchQueue.main.async {
                        proxy.scrollTo("terminal-bottom", anchor: .bottom)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("$")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    TextField("Command", text: $session.inputBuffer)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { session.sendLine() }
                    .disabled(!session.isRunning || session.isBusy)

                Button("Send") { session.sendLine() }
                    .disabled(!session.isRunning || session.isBusy || session.inputBuffer.isEmpty)
            }
            .padding(8)
            .background(Color.primary.opacity(0.04))
        }
        .frame(minHeight: 160)
        .onAppear {
            if !session.isRunning {
                session.start()
            }
        }
    }
}
