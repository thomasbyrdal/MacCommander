//
//  FileWatcher.swift
//  MacCommander
//

import Foundation

/// Monitors a directory for changes using DispatchSourceFileSystemObject.
///
/// Important: DispatchSource cancel/event handlers run on `queue`. Never call
/// `queue.sync` from those handlers or from a `queue.sync` block that cancels
/// the source — that deadlocks (seen when navigating to "..").
nonisolated final class FileWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var watchedPath: String?
    private let queue = DispatchQueue(label: "dk.byrdal.MacCommander.FileWatcher")
    private let lock = NSLock()
    private var changeHandler: (@Sendable () -> Void)?
    /// When true, FS events are dropped (used while reloading to avoid feedback loops).
    private var isSuspended = false

    var onChange: (@Sendable () -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return changeHandler
        }
        set {
            lock.lock()
            changeHandler = newValue
            lock.unlock()
        }
    }

    func watch(url: URL) {
        let path = url.standardizedFileURL.path

        lock.lock()
        let alreadyWatching = watchedPath == path && source != nil
        lock.unlock()
        if alreadyWatching {
            return
        }

        stop()

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            // Omit `.attrib` — directory listings touch attributes and can feedback-loop with reloads.
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let suspended = self.isSuspended
            let handler = self.changeHandler
            self.lock.unlock()
            guard !suspended else { return }
            handler?()
        }

        source.setCancelHandler { [weak self] in
            guard let self else {
                close(fd)
                return
            }
            self.lock.lock()
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
            self.lock.unlock()
        }

        lock.lock()
        fileDescriptor = fd
        watchedPath = path
        self.source = source
        isSuspended = false
        lock.unlock()

        source.resume()
    }

    func suspendEvents() {
        lock.lock()
        isSuspended = true
        lock.unlock()
    }

    func resumeEvents() {
        lock.lock()
        isSuspended = false
        lock.unlock()
    }

    func stop() {
        lock.lock()
        let sourceToCancel = source
        source = nil
        watchedPath = nil
        lock.unlock()

        sourceToCancel?.cancel()
    }

    deinit {
        stop()
    }
}
