//
//  KeyboardMonitor.swift
//  MacCommander
//

import AppKit
import SwiftUI

/// Captures commander-style key events that SwiftUI shortcuts alone don't cover well
/// (plain character quick-search, Insert, Space toggle, function keys without modifiers).
struct KeyboardMonitor: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyboardCatcherView {
        let view = KeyboardCatcherView()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyboardCatcherView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

final class KeyboardCatcherView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKeyDown?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
enum KeyboardCommandRouter {
    static func handle(_ event: NSEvent, app: AppViewModel) -> Bool {
        // Don't steal keys while sheets / text fields are editing.
        if app.operations.showCopyMoveSheet
            || app.operations.showDeleteConfirmation
            || app.operations.showNewFolderSheet
            || app.operations.showNewFileSheet
            || app.operations.showBatchRenameSheet
            || app.operations.renameTarget != nil
            || app.previewItem != nil
            || app.editItem != nil
            || app.hexItem != nil
            || app.compareResult != nil
            || app.showCompareSheet
            || app.showDuplicateFinder
            || app.showSettings {
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode
        let chars = event.charactersIgnoringModifiers ?? ""

        // Function keys
        switch keyCode {
        case 99: // F3
            if flags.contains(.option) {
                app.quickLookFocused()
            } else {
                app.previewFocused()
            }
            return true
        case 118: // F4
            app.editFocused()
            return true
        case 96: // F5
            app.copyToOtherPanel()
            return true
        case 97: // F6
            app.moveToOtherPanel()
            return true
        case 98: // F7
            app.presentNewFolder()
            return true
        case 100: // F8
            app.deleteSelection(permanent: flags.contains(.option))
            return true
        case 101: // F9
            app.showSettings = true
            return true
        case 109: // F10
            NSApp.terminate(nil)
            return true
        default:
            break
        }

        // Tab — switch panel (plain) / Ctrl+Tab cycle folder tabs
        if keyCode == 48 {
            if flags.contains(.control) {
                Task {
                    if flags.contains(.shift) {
                        await app.activePanel.selectPreviousTab()
                    } else {
                        await app.activePanel.selectNextTab()
                    }
                }
                return true
            }
            if !flags.contains(.command) {
                app.switchActivePanel()
                return true
            }
        }

        // Cmd+T new tab, Cmd+W close tab
        if chars.lowercased() == "t" && flags.contains(.command) && !flags.contains(.shift) {
            Task { await app.openNewTab() }
            return true
        }
        if chars.lowercased() == "w" && flags.contains(.command) && !flags.contains(.shift) {
            Task { await app.closeActiveTab() }
            return true
        }

        // Ctrl+` toggle terminal
        if chars == "`" && flags.contains(.control) {
            app.toggleTerminal()
            return true
        }

        // Space — Quick Look when focused item exists and no modifiers (commander-style)
        // Keep selection toggle on Space without modifiers was previous behavior.
        // Use Cmd+Space conflict avoidance: plain Space = toggle select, Option+Space = QL
        let panel = app.activePanel

        if keyCode == 49 { // Space
            if flags.contains(.option) {
                app.quickLookFocused()
                return true
            }
            if flags.isEmpty {
                panel.toggleSelectionOnFocused()
                return true
            }
        }

        // Navigation
        switch keyCode {
        case 126: // Up
            panel.moveFocus(by: -1)
            return true
        case 125: // Down
            panel.moveFocus(by: 1)
            return true
        case 115: // Home
            panel.moveFocusToStart()
            return true
        case 119: // End
            panel.moveFocusToEnd()
            return true
        case 36: // Return
            Task { await panel.openFocused() }
            return true
        case 51: // Delete / Backspace
            if flags.isEmpty {
                Task { await panel.goUp() }
                return true
            }
        case 114: // Insert (fn+return on some keyboards) — also handle with key equivalent
            panel.toggleSelectionAndMoveDown()
            return true
        default:
            break
        }

        // Cmd+Up = parent
        if keyCode == 126 && flags.contains(.command) && !flags.contains(.shift) {
            Task { await panel.goUp() }
            return true
        }

        // Cmd+Shift+H = Home
        if chars.lowercased() == "h" && flags.contains(.command) && flags.contains(.shift) {
            Task { await app.goHome() }
            return true
        }

        // Cmd+Shift+D = Desktop
        if chars.lowercased() == "d" && flags.contains(.command) && flags.contains(.shift) {
            Task { await app.goDesktop() }
            return true
        }

        // Cmd+Shift+. = toggle hidden
        if chars == "." && flags.contains(.command) && flags.contains(.shift) {
            app.toggleHiddenFiles()
            return true
        }

        // Escape clears quick search / selection
        if keyCode == 53 {
            if !panel.quickSearchQuery.isEmpty {
                panel.clearQuickSearch()
                return true
            }
            if !panel.selectedIDs.isEmpty {
                panel.clearSelection()
                return true
            }
            return false
        }

        // Quick search: printable characters without modifiers
        if flags.isEmpty || flags == [.shift] {
            if let character = event.characters?.first,
               character.isLetter || character.isNumber || character == "." || character == "-" || character == "_" {
                panel.appendQuickSearch(character)
                return true
            }
        }

        return false
    }
}
