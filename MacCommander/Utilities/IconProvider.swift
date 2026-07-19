//
//  IconProvider.swift
//  MacCommander
//

import AppKit
import UniformTypeIdentifiers

enum IconProvider {
    static func icon(for item: FileItem, size: CGFloat = 16) -> NSImage {
        if item.isParentEntry {
            return NSImage(systemSymbolName: "arrow.up.left", accessibilityDescription: "Parent")
                ?? NSWorkspace.shared.icon(forFile: "/")
        }

        let image = NSWorkspace.shared.icon(forFile: item.url.path)
        image.size = NSSize(width: size, height: size)
        return image
    }

    /// Cheap SF Symbol name — prefer extension over UTType (listing no longer fetches contentType).
    static func systemImageName(for item: FileItem) -> String {
        if item.isParentEntry { return "arrow.up.left" }
        if item.isDirectory { return "folder.fill" }
        if item.isSymbolicLink { return "link" }

        if let type = item.contentType {
            if type.conforms(to: .image) { return "photo" }
            if type.conforms(to: .movie) { return "film" }
            if type.conforms(to: .audio) { return "waveform" }
            if type.conforms(to: .pdf) { return "doc.richtext" }
            if type.conforms(to: .text) || type.conforms(to: .sourceCode) { return "doc.text" }
            if type.conforms(to: .archive) { return "doc.zipper" }
            if type.conforms(to: .application) { return "app.fill" }
        }

        switch item.fileExtension {
        case "png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic", "ico":
            return "photo"
        case "mp4", "mov", "m4v", "avi", "mkv", "webm":
            return "film"
        case "mp3", "m4a", "aac", "wav", "aiff", "flac", "ogg":
            return "waveform"
        case "pdf":
            return "doc.richtext"
        case "zip", "gz", "tgz", "bz2", "xz", "7z", "rar", "tar":
            return "doc.zipper"
        case "txt", "md", "rtf", "csv", "log",
             "swift", "json", "xml", "yml", "yaml",
             "html", "css", "js", "ts", "py", "rb", "sh",
             "c", "h", "cpp", "m", "mm", "go", "rs":
            return "doc.text"
        case "app":
            return "app.fill"
        default:
            return "doc"
        }
    }
}
