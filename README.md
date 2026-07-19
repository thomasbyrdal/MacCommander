# MacCommander

A dual-pane file manager for macOS, inspired by Norton Commander and Total Commander.

Built with **Swift 6** and **SwiftUI**, MacCommander focuses on keyboard-driven workflows, fast directory browsing, and familiar F-key operations — while still fitting naturally into the macOS desktop.

## Features

### Dual-pane browsing
- Side-by-side left and right panels with an active-pane highlight
- Per-panel tabs, each with its own path and navigation history
- Path field with tilde (`~`) expansion
- Back / forward / parent folder navigation
- Column sorting by name, size, date, or type (optional directories-first)
- Multi-select (click, Shift-range, Space / Insert)
- Incremental type-ahead quick search
- Live directory refresh via filesystem watching
- Favorites sidebar with bookmarks and mounted volumes

### File operations
- Copy and move between panels (confirm dialogs configurable in Settings)
- Delete to Trash, or permanent delete with Option+F8
- Rename and batch rename (`{name}`, `{ext}`, `{counter}`, `{date}`)
- New folder / new file, duplicate, compress (zip), extract zip archives
- Clipboard copy / cut / paste
- Drag and drop: **move** between panes; **copy** from Finder/external sources  
  (confirmation only when a name conflict exists at the destination)

### Preview and editing
- In-app preview (images, PDF, text/source, audio/video, folder metadata)
- Bottom preview pane (mutually exclusive with the terminal)
- System Quick Look integration
- Text editor for text-like files
- Hex editor for binary files

### Tools
- Compare left and right folders (only-left / only-right / identical / differ)
- Find duplicate files by content hash
- Embedded terminal panel (synced to the active folder; open in Terminal.app)
- Git status badges on files and branch info in the status bar

### Customization
- Classic / Light / Dark / System appearance
- Icon size, hidden files, default sort, startup folder
- Confirm delete / move / overwrite preferences
- Extensible plugin host (built-in sample: copy SHA-256 checksum)

## Architecture

MacCommander uses a layered MVVM-style structure with Swift Observation (`@Observable`) and `async`/`await` for I/O.

```
MacCommanderApp          WindowGroup, menus, About
  └─ ContentView         Owns AppViewModel
       └─ MainWindowView NavigationSplitView layout
            ├─ FavoritesSidebarView
            ├─ DualPaneView → FilePanelView × 2
            ├─ TerminalPanelView  XOR  BottomPreviewPanelView
            ├─ StatusBarView
            ├─ FunctionKeyBarView
            └─ KeyboardMonitor
```

| Layer | Location | Responsibility |
|-------|----------|----------------|
| **Models** | `MacCommander/Models/` | `FileItem`, settings, sort config, tabs, operation requests |
| **ViewModels** | `MacCommander/ViewModels/` | App coordination, per-panel state, file-op dialogs |
| **Services** | `MacCommander/Services/` | Filesystem I/O, watchers, git, terminal, compare, duplicates, Quick Look, plugins |
| **Views** | `MacCommander/Views/` | SwiftUI UI (panels, dialogs, chrome) |
| **Utilities** | `MacCommander/Utilities/` | Keyboard routing, formatters, path helpers, icons |

### Key types

- **`AppViewModel`** — App coordinator: both panels, active side, clipboard, sheets, terminal, plugins, drag/drop, git, compare, and duplicates.
- **`PanelViewModel`** — One pane: current URL, listing, sort/focus/selection, tabs, history, quick search, directory watcher.
- **`FileOperationViewModel`** — Copy/move/delete/rename/batch-rename/new-item flows backed by `FileService`.
- **`FileService`** — Listing and transfers off the main actor for responsiveness.

Directory listing and sorting run in background tasks; the UI keeps a cached sorted list so navigation stays responsive.

> **Note:** App Sandbox is intentionally **off** so the app can browse and manage the full filesystem like a traditional commander-style manager.

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| **Tab** | Switch active panel |
| **F3** | Preview focused item |
| **⌥F3** / **⌘Y** | Quick Look |
| **F4** | Edit (text) or hex editor (binary) |
| **F5** / **F6** | Copy / Move to other panel |
| **F7** | New folder |
| **F8** / **⌥F8** | Delete / Permanent delete |
| **F9** | Settings |
| **F10** | Quit |
| **⌘↑** | Parent folder |
| **⌘⇧H** / **⌘⇧D** | Home / Desktop |
| **⌘T** / **⌘W** | New tab / Close tab |
| **⌃Tab** / **⌃⇧Tab** | Next / previous tab |
| **⌃\`** | Toggle terminal |
| **⌃⇧P** | Toggle preview pane |
| **⌘⇧R** | Batch rename |
| **⌘⌥D** | Compare panels |
| **⌘⇧D** | Find duplicates |
| **⌘⌥H** | Hex editor |
| **⌘⇧.** | Toggle hidden files |
| **Space** | Toggle selection on focused item |
| **Esc** | Clear quick search or selection |

## Requirements

- macOS 26.5 or later
- Xcode 26 (Swift 6)

## Building

1. Open `MacCommander.xcodeproj` in Xcode.
2. Select the **MacCommander** scheme (My Mac).
3. Build and run (**⌘R**).

Ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`) is configured for local builds.

## Tests

Unit tests live in `MacCommanderTests/` (Swift Testing):

- File listing / create / rename / trash / copy
- Path formatting (`~`)
- Sort configuration
- Batch rename
- Directory compare
- Duplicate detection

UI tests in `MacCommanderUITests/` cover basic launch.

Run tests from Xcode (**⌘U**) or:

```bash
xcodebuild -scheme MacCommander -destination 'platform=macOS' test
```

## Project layout

```
MacCommander/
├── MacCommander/           # App sources
│   ├── Models/
│   ├── ViewModels/
│   ├── Services/
│   ├── Views/
│   ├── Utilities/
│   ├── Resources/          # App icon assets
│   └── Assets.xcassets/
├── MacCommanderTests/
├── MacCommanderUITests/
├── Info.plist
└── MacCommander.xcodeproj
```

## License

Copyright © 2026 byrdal.dk. All rights reserved.
