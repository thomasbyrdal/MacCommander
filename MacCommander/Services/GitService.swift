//
//  GitService.swift
//  MacCommander
//

import Foundation

nonisolated enum GitFileStatus: String, Sendable, Equatable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"
    case conflict = "U"
    case unknown = " "

    var title: String {
        switch self {
        case .modified: "Modified"
        case .added: "Added"
        case .deleted: "Deleted"
        case .renamed: "Renamed"
        case .copied: "Copied"
        case .untracked: "Untracked"
        case .ignored: "Ignored"
        case .conflict: "Conflict"
        case .unknown: "Clean"
        }
    }
}

nonisolated struct GitRepoStatus: Sendable {
    let root: URL
    let branch: String
    let statuses: [String: GitFileStatus] // relative path -> status

    func status(for url: URL) -> GitFileStatus? {
        let rootPath = root.standardizedFileURL.path
        var relative = String(url.standardizedFileURL.path.dropFirst(rootPath.count))
        if relative.hasPrefix("/") { relative.removeFirst() }
        return statuses[relative]
    }
}

nonisolated enum GitService {
    static func repositoryRoot(containing url: URL) async -> URL? {
        await Task.detached(priority: .utility) {
            let result = runGit(["rev-parse", "--show-toplevel"], cwd: url)
            guard result.exitCode == 0 else { return nil }
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }.value
    }

    static func status(forDirectory url: URL) async -> GitRepoStatus? {
        await Task.detached(priority: .utility) {
            guard let root = repositoryRootSync(containing: url) else { return nil }

            let branchResult = runGit(["rev-parse", "--abbrev-ref", "HEAD"], cwd: root)
            let branch = branchResult.exitCode == 0
                ? branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                : "unknown"

            // Scope to the viewed directory only — whole-repo `status -u` can burn
            // many seconds of CPU in large trees and freeze the UI.
            let statusResult = runGit(["status", "--porcelain", "-u", "--", "."], cwd: url)
            guard statusResult.exitCode == 0 else {
                return GitRepoStatus(root: root, branch: branch, statuses: [:])
            }

            let rootPath = root.standardizedFileURL.path
            let dirPath = url.standardizedFileURL.path
            let prefix: String
            if dirPath.hasPrefix(rootPath) {
                var relativeDir = String(dirPath.dropFirst(rootPath.count))
                if relativeDir.hasPrefix("/") { relativeDir.removeFirst() }
                prefix = relativeDir.isEmpty ? "" : relativeDir + "/"
            } else {
                prefix = ""
            }

            var map: [String: GitFileStatus] = [:]
            for line in statusResult.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
                let raw = String(line)
                guard raw.count >= 4 else { continue }
                let code = parseStatusCode(raw)
                let pathPart = String(raw.dropFirst(3))
                let localPath: String
                if let arrow = pathPart.range(of: " -> ") {
                    localPath = String(pathPart[arrow.upperBound...])
                } else {
                    localPath = pathPart
                }
                // Porcelain paths are relative to cwd (url); store repo-relative for lookups.
                let repoRelative = prefix + localPath
                map[repoRelative] = code
            }

            return GitRepoStatus(root: root, branch: branch, statuses: map)
        }.value
    }

    private static func repositoryRootSync(containing url: URL) -> URL? {
        let result = runGit(["rev-parse", "--show-toplevel"], cwd: url)
        guard result.exitCode == 0 else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func parseStatusCode(_ line: String) -> GitFileStatus {
        let chars = Array(line.prefix(2))
        guard chars.count == 2 else { return .unknown }
        if chars[0] == "U" || chars[1] == "U" || (chars[0] == "A" && chars[1] == "A") {
            return .conflict
        }
        if chars[0] == "?" || chars[1] == "?" { return .untracked }
        if chars[0] == "!" || chars[1] == "!" { return .ignored }

        let relevant = chars[0] != " " ? chars[0] : chars[1]
        switch relevant {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        default: return .unknown
        }
    }

    private struct GitCommandResult: Sendable {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private static func runGit(_ arguments: [String], cwd: URL) -> GitCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = cwd
        process.environment = ProcessInfo.processInfo.environment

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return GitCommandResult(exitCode: 127, stdout: "", stderr: error.localizedDescription)
        }

        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return GitCommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
