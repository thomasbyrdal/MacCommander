//
//  SortConfiguration.swift
//  MacCommander
//

import Foundation

nonisolated enum SortColumn: String, CaseIterable, Codable, Sendable, Identifiable {
    case name
    case size
    case date
    case type

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Name"
        case .size: "Size"
        case .date: "Date"
        case .type: "Type"
        }
    }
}

nonisolated enum SortOrder: String, CaseIterable, Sendable {
    case ascending
    case descending

    var opposite: SortOrder {
        self == .ascending ? .descending : .ascending
    }
}

nonisolated struct SortConfiguration: Equatable, Sendable {
    var column: SortColumn = .name
    var order: SortOrder = .ascending
    var directoriesFirst: Bool = true

    func sorted(_ items: [FileItem]) -> [FileItem] {
        let parent = items.filter(\.isParentEntry)
        let rest = items.filter { !$0.isParentEntry }

        let sortedRest = rest.sorted { lhs, rhs in
            if directoriesFirst, lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }

            let comparison: ComparisonResult
            switch column {
            case .name:
                comparison = lhs.name.localizedStandardCompare(rhs.name)
            case .size:
                if lhs.size == rhs.size {
                    comparison = lhs.name.localizedStandardCompare(rhs.name)
                } else {
                    comparison = lhs.size < rhs.size ? .orderedAscending : .orderedDescending
                }
            case .date:
                let left = lhs.modificationDate ?? .distantPast
                let right = rhs.modificationDate ?? .distantPast
                if left == right {
                    comparison = lhs.name.localizedStandardCompare(rhs.name)
                } else {
                    comparison = left < right ? .orderedAscending : .orderedDescending
                }
            case .type:
                comparison = lhs.displayType.localizedStandardCompare(rhs.displayType)
                if comparison == .orderedSame {
                    return order == .ascending
                        ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                        : lhs.name.localizedStandardCompare(rhs.name) == .orderedDescending
                }
            }

            return order == .ascending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }

        return parent + sortedRest
    }
}
