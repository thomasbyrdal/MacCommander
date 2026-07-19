//
//  PaneSide.swift
//  MacCommander
//

import Foundation

enum PaneSide: String, CaseIterable, Sendable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var opposite: PaneSide {
        switch self {
        case .left: .right
        case .right: .left
        }
    }
}
