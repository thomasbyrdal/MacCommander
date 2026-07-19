//
//  AppTheme.swift
//  MacCommander
//

import SwiftUI

/// Visual palette applied across the main window. `.standard` keeps system colors;
/// `.classic` recreates the Norton Commander look.
struct AppTheme: Equatable, Sendable {
    var isClassic: Bool

    var background: Color
    var panelBackground: Color
    var text: Color
    var secondaryText: Color
    var tertiaryText: Color
    var columnHeader: Color
    var previewText: Color
    var directoryIcon: Color
    var selectionFill: Color
    var selectionText: Color
    var inactiveSelectionFill: Color
    var accentBorder: Color
    var chromeBackground: Color
    var pathHeaderFill: Color
    var columnHeaderFill: Color
    var functionKeyFill: Color

    /// System / Light / Dark — rely on semantic SwiftUI colors.
    static let standard = AppTheme(
        isClassic: false,
        background: Color(nsColor: .windowBackgroundColor),
        panelBackground: Color(nsColor: .textBackgroundColor),
        text: Color.primary,
        secondaryText: Color.secondary,
        tertiaryText: Color.secondary.opacity(0.7),
        columnHeader: Color.primary,
        previewText: Color.primary,
        directoryIcon: Color.accentColor,
        selectionFill: Color.accentColor.opacity(0.28),
        selectionText: Color.primary,
        inactiveSelectionFill: Color.accentColor.opacity(0.12),
        accentBorder: Color.accentColor,
        chromeBackground: Color(nsColor: .windowBackgroundColor),
        pathHeaderFill: Color.accentColor.opacity(0.08),
        columnHeaderFill: Color.primary.opacity(0.05),
        functionKeyFill: Color.primary.opacity(0.06)
    )

    /// Norton Commander–style palette.
    static let classic = AppTheme(
        isClassic: true,
        // DOS NC navy / cyan / yellow
        background: Color(red: 0.0, green: 0.0, blue: 0.50),
        panelBackground: Color(red: 0.0, green: 0.0, blue: 0.55),
        text: Color(red: 0.33, green: 0.85, blue: 0.95),
        secondaryText: Color(red: 0.45, green: 0.75, blue: 0.95),
        tertiaryText: Color(red: 0.35, green: 0.65, blue: 0.90),
        columnHeader: Color(red: 1.0, green: 0.92, blue: 0.20),
        previewText: Color.white,
        directoryIcon: Color(red: 1.0, green: 0.92, blue: 0.20),
        selectionFill: Color(red: 0.0, green: 0.70, blue: 0.70),
        selectionText: Color(red: 0.0, green: 0.0, blue: 0.45),
        inactiveSelectionFill: Color(red: 0.0, green: 0.45, blue: 0.55),
        accentBorder: Color(red: 1.0, green: 0.92, blue: 0.20),
        chromeBackground: Color(red: 0.0, green: 0.0, blue: 0.42),
        pathHeaderFill: Color(red: 0.0, green: 0.0, blue: 0.62),
        columnHeaderFill: Color(red: 0.0, green: 0.0, blue: 0.40),
        functionKeyFill: Color(red: 0.0, green: 0.35, blue: 0.55)
    )
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.standard
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension View {
    func appTheme(_ theme: AppTheme) -> some View {
        environment(\.appTheme, theme)
    }
}
