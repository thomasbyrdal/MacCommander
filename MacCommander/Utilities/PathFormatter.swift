//
//  PathFormatter.swift
//  MacCommander
//

import Foundation

nonisolated enum PathFormatter {
    static func displayPath(for url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    static func resolve(_ path: String) -> URL {
        if path == "~" || path.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser
            if path == "~" { return home }
            let remainder = String(path.dropFirst(2))
            return home.appendingPathComponent(remainder)
        }
        return URL(fileURLWithPath: path)
    }
}
