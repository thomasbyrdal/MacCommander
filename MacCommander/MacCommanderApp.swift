//
//  MacCommanderApp.swift
//  MacCommander
//

import AppKit
import SwiftUI

@main
struct MacCommanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 760)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MacCommander") {
                    AppIcon.showAboutPanel()
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("New Folder…") {
                    NotificationCenter.default.post(name: .macCommanderNewFolder, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New File…") {
                    NotificationCenter.default.post(name: .macCommanderNewFile, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("New Tab") {
                    NotificationCenter.default.post(name: .macCommanderNewTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    NotificationCenter.default.post(name: .macCommanderCloseTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandMenu("Go") {
                Button("Parent Folder") {
                    NotificationCenter.default.post(name: .macCommanderGoUp, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Button("Home") {
                    NotificationCenter.default.post(name: .macCommanderGoHome, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Desktop") {
                    NotificationCenter.default.post(name: .macCommanderGoDesktop, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            CommandMenu("File Operations") {
                Button("Copy to Other Panel") {
                    NotificationCenter.default.post(name: .macCommanderCopy, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Move to Other Panel") {
                    NotificationCenter.default.post(name: .macCommanderMove, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Delete…") {
                    NotificationCenter.default.post(name: .macCommanderDelete, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)

                Divider()

                Button("Batch Rename…") {
                    NotificationCenter.default.post(name: .macCommanderBatchRename, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Compare Panels") {
                    NotificationCenter.default.post(name: .macCommanderCompare, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])

                Button("Find Duplicates…") {
                    NotificationCenter.default.post(name: .macCommanderFindDuplicates, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Quick Look") {
                    NotificationCenter.default.post(name: .macCommanderQuickLook, object: nil)
                }
                .keyboardShortcut("y", modifiers: .command)

                Button("Hex Editor") {
                    NotificationCenter.default.post(name: .macCommanderHexEditor, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .option])

                Divider()

                Button("Copy") {
                    NotificationCenter.default.post(name: .macCommanderClipboardCopy, object: nil)
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Cut") {
                    NotificationCenter.default.post(name: .macCommanderClipboardCut, object: nil)
                }
                .keyboardShortcut("x", modifiers: .command)

                Button("Paste") {
                    NotificationCenter.default.post(name: .macCommanderClipboardPaste, object: nil)
                }
                .keyboardShortcut("v", modifiers: .command)

                Divider()

                Button("Refresh") {
                    NotificationCenter.default.post(name: .macCommanderRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Toggle Terminal") {
                    NotificationCenter.default.post(name: .macCommanderToggleTerminal, object: nil)
                }
                .keyboardShortcut("`", modifiers: .control)

                Button("Toggle Preview") {
                    NotificationCenter.default.post(name: .macCommanderTogglePreview, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.control, .shift])
            }
        }
        // Additional windows: File → New Window (system) opens another WindowGroup instance.

        Settings {
            Text("Open Settings from the toolbar or press F9.")
                .frame(width: 320, height: 80)
        }
    }
}

/// Loads `Resources/icon.png` / `AppIcon.icns` and applies them for Dock + About.
enum AppIcon {
    private static var aboutWindow: NSWindow?

    static func applyToRunningApplication() {
        guard let image = loadImage() else { return }
        // Force the Dock tile for this process — avoids stale Icon Services / generic white icons.
        NSApplication.shared.applicationIconImage = image
    }

    /// Shows a custom About window. The system About panel clamps icons and cannot show 1024×1024 artwork.
    static func showAboutPanel() {
        if let aboutWindow, aboutWindow.isVisible {
            aboutWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "About MacCommander"
        window.styleMask = [.titled, .closable]
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }

    static func closeAboutPanel() {
        aboutWindow?.close()
        aboutWindow = nil
    }

    /// Full-resolution 1024×1024 icon for the About dialog.
    static func loadAboutIcon() -> NSImage? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "AppIcon-1024", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 1024, height: 1024)
            return image
        }
        // Fallback: downscale the master icon.png into a 1024×1024 image.
        guard let source = loadImage() else { return nil }
        let size = NSSize(width: 1024, height: 1024)
        let icon = NSImage(size: size)
        icon.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: source.size),
            operation: .copy,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        icon.unlockFocus()
        return icon
    }

    static func loadImage() -> NSImage? {
        let bundle = Bundle.main
        // Prefer the full PNG / custom icns over the asset-catalog AppIcon (can be a blank placeholder).
        if let url = bundle.url(forResource: "icon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = bundle.url(forResource: "MacCommander", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = bundle.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let image = bundle.image(forResource: "icon") {
            return image
        }
        return nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppIcon.applyToRunningApplication()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppIcon.applyToRunningApplication()
    }
}

extension Notification.Name {
    static let macCommanderNewFolder = Notification.Name("macCommanderNewFolder")
    static let macCommanderNewFile = Notification.Name("macCommanderNewFile")
    static let macCommanderGoUp = Notification.Name("macCommanderGoUp")
    static let macCommanderGoHome = Notification.Name("macCommanderGoHome")
    static let macCommanderGoDesktop = Notification.Name("macCommanderGoDesktop")
    static let macCommanderCopy = Notification.Name("macCommanderCopy")
    static let macCommanderMove = Notification.Name("macCommanderMove")
    static let macCommanderDelete = Notification.Name("macCommanderDelete")
    static let macCommanderClipboardCopy = Notification.Name("macCommanderClipboardCopy")
    static let macCommanderClipboardCut = Notification.Name("macCommanderClipboardCut")
    static let macCommanderClipboardPaste = Notification.Name("macCommanderClipboardPaste")
    static let macCommanderRefresh = Notification.Name("macCommanderRefresh")
    static let macCommanderBatchRename = Notification.Name("macCommanderBatchRename")
    static let macCommanderCompare = Notification.Name("macCommanderCompare")
    static let macCommanderQuickLook = Notification.Name("macCommanderQuickLook")
    static let macCommanderNewTab = Notification.Name("macCommanderNewTab")
    static let macCommanderCloseTab = Notification.Name("macCommanderCloseTab")
    static let macCommanderToggleTerminal = Notification.Name("macCommanderToggleTerminal")
    static let macCommanderTogglePreview = Notification.Name("macCommanderTogglePreview")
    static let macCommanderFindDuplicates = Notification.Name("macCommanderFindDuplicates")
    static let macCommanderHexEditor = Notification.Name("macCommanderHexEditor")
}
