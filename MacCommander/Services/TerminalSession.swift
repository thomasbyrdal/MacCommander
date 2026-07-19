//
//  TerminalSession.swift
//  MacCommander
//

import Darwin
import Foundation
import Observation

/// Shell panel that runs each command as a separate process.
/// Avoids long-lived Pipe/DispatchSource setups that trip FileHandle queue assertions on modern macOS.
@MainActor
@Observable
final class TerminalSession {
    private(set) var output: String = ""
    private(set) var isRunning = false
    private(set) var isBusy = false
    private(set) var currentDirectory: URL
    var inputBuffer: String = ""

    private let processBox = ProcessBox()
    private let maxOutputCharacters = 200_000
    private let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.currentDirectory = directory
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        appendOutput("Shell ready — \(currentDirectory.path)\n")
        appendOutput("Type commands below. Use `cd` to change directory.\n\n")
    }

    func stop() {
        processBox.process?.terminate()
        processBox.process = nil
        isBusy = false
        isRunning = false
    }

    func sendLine(_ line: String? = nil) {
        let text = (line ?? inputBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
        if line == nil {
            inputBuffer = ""
        }
        guard isRunning, !text.isEmpty else { return }
        guard !isBusy else {
            appendOutput("⏳ Wait for the current command to finish.\n")
            return
        }

        appendOutput("$ \(text)\n")

        if text == "clear" || text == "cls" {
            clear()
            return
        }

        if let newDirectory = resolveCd(text) {
            currentDirectory = newDirectory
            appendOutput("cwd: \(currentDirectory.path)\n")
            return
        }

        isBusy = true
        let directory = currentDirectory
        let shell = shellPath
        let box = processBox

        Task.detached(priority: .userInitiated) {
            let result = Self.run(command: text, shell: shell, directory: directory, processBox: box)
            await MainActor.run {
                self.appendOutput(result)
                if !result.isEmpty && !result.hasSuffix("\n") {
                    self.appendOutput("\n")
                }
                self.isBusy = false
                box.process = nil
            }
        }
    }

    func sendInterrupt() {
        processBox.process?.interrupt()
        processBox.process = nil
        appendOutput("^C\n")
        isBusy = false
    }

    func changeDirectory(to url: URL) {
        currentDirectory = url
        if isRunning {
            appendOutput("cwd: \(url.path)\n")
        }
    }

    func clear() {
        output = ""
    }

    // MARK: - Private

    private func resolveCd(_ text: String) -> URL? {
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let command = parts.first, command == "cd" else { return nil }

        let argument: String
        if parts.count == 1 {
            argument = "~"
        } else {
            argument = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if argument == "~" || argument.hasPrefix("~/") {
            return PathFormatter.resolve(argument)
        }
        if argument.hasPrefix("/") {
            return URL(fileURLWithPath: argument, isDirectory: true)
        }
        return currentDirectory.appendingPathComponent(argument).standardizedFileURL
    }

    private func appendOutput(_ text: String) {
        output += text
        if output.count > maxOutputCharacters {
            output = String(output.suffix(maxOutputCharacters))
        }
    }

    /// Runs a shell command off the main actor using only Darwin I/O for reading.
    nonisolated private static func run(
        command: String,
        shell: String,
        directory: URL,
        processBox: ProcessBox
    ) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = directory
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stdoutPipe

        let readFD = dup(stdoutPipe.fileHandleForReading.fileDescriptor)
        guard readFD >= 0 else {
            return "Failed to set up output pipe.\n"
        }
        defer { Darwin.close(readFD) }

        processBox.process = process

        do {
            try process.run()
        } catch {
            processBox.process = nil
            return "Failed to run command: \(error.localizedDescription)\n"
        }

        // Read concurrently so a full pipe buffer cannot deadlock the child.
        let collected = OutBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            var buffer = [UInt8](repeating: 0, count: 16_384)
            var data = Data()
            while true {
                let count = Darwin.read(readFD, &buffer, buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            collected.data = data
            group.leave()
        }

        process.waitUntilExit()
        group.wait()
        processBox.process = nil

        let output = String(data: collected.data, encoding: .utf8)
            ?? String(decoding: collected.data, as: UTF8.self)
        if process.terminationStatus != 0 && output.isEmpty {
            return "Command exited with status \(process.terminationStatus)\n"
        }
        return output
    }
}

/// Shared process handle for interrupt support.
nonisolated private final class ProcessBox: @unchecked Sendable {
    var process: Process?
}

/// Tiny box so the reader closure can publish Data without actor isolation issues.
nonisolated private final class OutBox: @unchecked Sendable {
    var data = Data()
}
