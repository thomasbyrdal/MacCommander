//
//  FilePreviewContent.swift
//  MacCommander
//

import AppKit
import AVKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Shared preview body used by the sheet preview and the bottom preview pane.
struct FilePreviewContent: View {
    let item: FileItem
    var pluginOverride: AnyView? = nil
    var onQuickLook: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @State private var textPreview: TextPreviewPayload?
    @State private var isLoadingText = false

    var body: some View {
        Group {
            if let pluginOverride {
                pluginOverride
            } else if item.isDirectory {
                metadataView
            } else if isUnsupportedBinary {
                unsupportedPreview
            } else if isImage {
                imagePreview
            } else if isPDF {
                PDFPreviewRepresentable(url: item.url)
            } else if isVideo || isAudio {
                MediaPreviewView(url: item.url)
            } else if isTextFile {
                textPreviewBody
            } else {
                unsupportedPreview
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: item.id) {
            textPreview = nil
            guard isTextFile, !item.isDirectory, !isUnsupportedBinary else { return }
            isLoadingText = true
            let url = item.url
            let loaded = await Task.detached(priority: .userInitiated) {
                Self.loadTextPreview(from: url)
            }.value
            guard !Task.isCancelled else { return }
            textPreview = loaded
            isLoadingText = false
        }
    }

    /// Formats that should never be sniffed as text/media in the live preview pane.
    private var isUnsupportedBinary: Bool {
        let binaryExtensions: Set<String> = [
            "docx", "doc", "xlsx", "xls", "pptx", "ppt",
            "pages", "numbers", "key",
            "odt", "ods", "odp",
            "zip", "gz", "tgz", "bz2", "xz", "7z", "rar", "tar",
            "dmg", "pkg", "iso",
            "exe", "dll", "so", "dylib",
            "app", "bundle",
            "sqlite", "db",
            "psd", "ai", "sketch"
        ]
        return binaryExtensions.contains(item.fileExtension)
    }

    private var isImage: Bool {
        item.contentType?.conforms(to: .image) == true
            || ["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic"].contains(item.fileExtension)
    }

    private var isPDF: Bool {
        item.fileExtension == "pdf" || item.contentType?.conforms(to: .pdf) == true
    }

    private var isVideo: Bool {
        item.contentType?.conforms(to: .movie) == true
            || ["mp4", "mov", "m4v", "avi", "mkv"].contains(item.fileExtension)
    }

    private var isAudio: Bool {
        item.contentType?.conforms(to: .audio) == true
            || ["mp3", "m4a", "aac", "wav", "aiff", "flac"].contains(item.fileExtension)
    }

    private var isTextFile: Bool {
        if let type = item.contentType {
            if type.conforms(to: .text) || type.conforms(to: .sourceCode) || type.conforms(to: .json) || type.conforms(to: .xml) {
                return true
            }
        }
        let textExtensions: Set<String> = [
            "txt", "md", "swift", "json", "xml", "yml", "yaml", "csv", "log",
            "html", "css", "js", "ts", "py", "rb", "sh", "c", "h", "cpp", "m", "mm"
        ]
        return textExtensions.contains(item.fileExtension)
    }

    @ViewBuilder
    private var imagePreview: some View {
        // Decode off the critical path would be nicer; keep simple but avoid Form thrash.
        if let image = NSImage(contentsOf: item.url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            unsupportedPreview
        }
    }

    @ViewBuilder
    private var textPreviewBody: some View {
        if isLoadingText, textPreview == nil {
            ProgressView("Loading preview…")
                .tint(theme.previewText)
        } else if let textPreview {
            VStack(spacing: 0) {
                TextPreviewRepresentable(
                    text: textPreview.text,
                    textColor: NSColor(theme.previewText),
                    backgroundColor: NSColor(theme.panelBackground)
                )
                if let note = textPreview.truncationNote {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.chromeBackground)
                }
            }
        } else {
            Text("Unable to read file.")
                .foregroundStyle(theme.secondaryText)
        }
    }

    /// Avoid SwiftUI `Form` here — nested Forms in the bottom pane can layout-thrash at 100% CPU.
    private var metadataView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                metadataRow("Name", item.name)
                metadataRow("Path", item.url.path)
                metadataRow("Type", item.displayType)
                metadataRow("Size", item.isParentEntry ? "" : item.displaySize)
                metadataRow("Modified", item.isParentEntry ? "—" : item.displayDate)
                metadataRow("Symbolic Link", item.isSymbolicLink ? "Yes" : "No")
                if onQuickLook != nil {
                    Button("Open in Quick Look") {
                        onQuickLook?()
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background(theme.panelBackground)
    }

    private var unsupportedPreview: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc")
                .font(.system(size: 36))
                .foregroundStyle(theme.secondaryText)
            Text(item.name)
                .font(.headline)
                .foregroundStyle(theme.previewText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text("\(item.displayType) · \(item.displaySize)")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            Text("Preview not available for this file type.")
                .font(.caption)
                .foregroundStyle(theme.tertiaryText)
            if onQuickLook != nil {
                Button("Open in Quick Look") {
                    onQuickLook?()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .background(theme.panelBackground)
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.columnHeader)
            Text(value)
                .font(.body.monospaced())
                .foregroundStyle(theme.previewText)
                .textSelection(.enabled)
        }
    }

    private nonisolated static func loadTextPreview(from url: URL) -> TextPreviewPayload {
        // Partial read only — never map the whole file for preview.
        let maxBytes = 96_000
        let maxLines = 2_500
        let maxLineChars = 2_000

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return TextPreviewPayload(text: "Unable to read file.", truncationNote: nil)
        }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: maxBytes + 1)
        guard !data.isEmpty else {
            return TextPreviewPayload(text: "", truncationNote: nil)
        }

        let hitByteLimit = data.count > maxBytes
        let slice = hitByteLimit ? data.prefix(maxBytes) : data[...]

        let nulCount = slice.prefix(4_096).filter { $0 == 0 }.count
        if nulCount > 4 {
            return TextPreviewPayload(text: "Binary file — preview unavailable.", truncationNote: nil)
        }

        guard var text = String(data: Data(slice), encoding: .utf8)
                ?? String(data: Data(slice), encoding: .isoLatin1) else {
            return TextPreviewPayload(text: "Binary file — preview unavailable.", truncationNote: nil)
        }

        // Cap lines and extreme line lengths so layout stays cheap.
        var truncatedByLines = false
        var truncatedByLineLength = false
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let limitedLines: [Substring]
        if lines.count > maxLines {
            truncatedByLines = true
            limitedLines = Array(lines.prefix(maxLines))
        } else {
            limitedLines = Array(lines)
        }

        text = limitedLines.map { line in
            if line.count > maxLineChars {
                truncatedByLineLength = true
                return String(line.prefix(maxLineChars)) + "…"
            }
            return String(line)
        }.joined(separator: "\n")

        var notes: [String] = []
        if hitByteLimit || truncatedByLines || truncatedByLineLength {
            let total = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }
            if let total {
                notes.append("Preview truncated · \(Formatters.byteCountString(total)) total")
            } else {
                notes.append("Preview truncated")
            }
        }

        return TextPreviewPayload(
            text: text,
            truncationNote: notes.isEmpty ? nil : notes.joined(separator: " · ")
        )
    }
}

nonisolated struct TextPreviewPayload: Sendable {
    let text: String
    let truncationNote: String?
}

/// AppKit text view — SwiftUI `Text`/`ScrollView` is extremely slow for large ASCII dumps.
struct TextPreviewRepresentable: NSViewRepresentable {
    let text: String
    var textColor: NSColor = .labelColor
    var backgroundColor: NSColor = .textBackgroundColor

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.string = text
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.drawsBackground = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            textView.scrollToBeginningOfDocument(nil)
        }
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(
                width: max(scrollView.contentSize.width, 1),
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }
}

struct MediaPreviewView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView("Loading media…")
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: url) { _, newURL in
            player?.pause()
            player = AVPlayer(url: newURL)
            player?.play()
        }
    }
}

struct PDFPreviewRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}
