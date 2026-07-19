//
//  BatchRenameService.swift
//  MacCommander
//

import Foundation

nonisolated struct BatchRenameItem: Identifiable, Sendable, Hashable {
    var id: URL { source }
    let source: URL
    var proposedName: String

    var destination: URL {
        source.deletingLastPathComponent().appendingPathComponent(proposedName)
    }

    var isChanged: Bool {
        proposedName != source.lastPathComponent
    }

    var hasCollision: Bool {
        proposedName != source.lastPathComponent
            && FileManager.default.fileExists(atPath: destination.path)
    }
}

nonisolated struct BatchRenamePlan: Sendable {
    var items: [BatchRenameItem]

    var changedCount: Int { items.filter(\.isChanged).count }
    var collisionCount: Int { items.filter(\.hasCollision).count }
}

nonisolated enum BatchRenameService {
    /// Supports tokens: `{name}`, `{ext}`, `{counter}`, `{date}`
    /// Example: `{name}_{counter}.{ext}` or `photo_{counter}.jpg`
    static func preview(
        urls: [URL],
        template: String,
        startIndex: Int = 1,
        date: Date = Date()
    ) -> BatchRenamePlan {
        let dateStamp = date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        var counter = startIndex

        let items = urls.map { url -> BatchRenameItem in
            let fullName = url.lastPathComponent
            let ext = url.pathExtension
            let name: String
            if ext.isEmpty {
                name = fullName
            } else {
                name = String(fullName.dropLast(ext.count + 1))
            }

            var proposed = template
            proposed = proposed.replacingOccurrences(of: "{name}", with: name)
            proposed = proposed.replacingOccurrences(of: "{ext}", with: ext)
            proposed = proposed.replacingOccurrences(of: "{counter}", with: String(counter))
            proposed = proposed.replacingOccurrences(of: "{date}", with: dateStamp)

            // If template has no extension and original did, preserve extension.
            if !ext.isEmpty, !proposed.contains("."), !template.contains("{ext}") {
                proposed += ".\(ext)"
            }

            counter += 1
            return BatchRenameItem(source: url, proposedName: proposed)
        }

        return BatchRenamePlan(items: items)
    }

    static func apply(_ plan: BatchRenamePlan, skipCollisions: Bool) throws -> Int {
        var renamed = 0
        let fileManager = FileManager.default

        // Rename in two phases when needed to avoid intermediate collisions.
        // First pass: rename to temporary unique names for items that would collide with each other.
        var working: [(from: URL, to: URL)] = []

        for item in plan.items where item.isChanged {
            if item.hasCollision {
                if skipCollisions { continue }
                throw FileOperationError.destinationExists(item.destination)
            }
            working.append((item.source, item.destination))
        }

        // Detect within-plan destination collisions.
        var seenDestinations = Set<String>()
        for pair in working {
            let path = pair.to.path
            if seenDestinations.contains(path) {
                throw FileOperationError.underlying("Duplicate destination name in plan: \(pair.to.lastPathComponent)")
            }
            seenDestinations.insert(path)
        }

        for pair in working {
            // Skip if source already moved / missing.
            guard fileManager.fileExists(atPath: pair.from.path) else { continue }
            if fileManager.fileExists(atPath: pair.to.path) {
                if skipCollisions { continue }
                throw FileOperationError.destinationExists(pair.to)
            }
            try fileManager.moveItem(at: pair.from, to: pair.to)
            renamed += 1
        }

        return renamed
    }
}
