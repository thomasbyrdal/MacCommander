//
//  FileOperationViewModel.swift
//  MacCommander
//

import Foundation
import Observation

@MainActor
@Observable
final class FileOperationViewModel {
    var activeRequest: FileOperationRequest?
    var progress: FileOperationProgress?
    var isRunning = false
    var errorMessage: String?
    var renameTarget: FileItem?
    var renameText: String = ""
    var newFolderName: String = "New Folder"
    var newFileName: String = "untitled.txt"
    var showNewFolderSheet = false
    var showNewFileSheet = false
    var showDeleteConfirmation = false
    var pendingDeletePermanent = false
    var showCopyMoveSheet = false
    var showBatchRenameSheet = false
    var batchRenameURLs: [URL] = []
    var batchRenameTemplate: String = "{name}_{counter}"
    var batchRenameStartIndex: Int = 1
    var batchRenameSkipCollisions = true
    var batchRenamePlan: BatchRenamePlan?

    private let fileService: FileServiceProtocol
    private var runningTask: Task<Void, Never>?

    init(fileService: FileServiceProtocol) {
        self.fileService = fileService
    }

    func beginCopy(sources: [URL], destination: URL, overwritePolicy: OverwritePolicy) {
        activeRequest = FileOperationRequest(
            kind: .copy,
            sources: sources,
            destination: destination,
            overwritePolicy: overwritePolicy
        )
        showCopyMoveSheet = true
    }

    func beginMove(sources: [URL], destination: URL, overwritePolicy: OverwritePolicy, showConfirmation: Bool = true) {
        activeRequest = FileOperationRequest(
            kind: .move,
            sources: sources,
            destination: destination,
            overwritePolicy: overwritePolicy
        )
        showCopyMoveSheet = showConfirmation
    }

    func beginDelete(sources: [URL], permanent: Bool) {
        activeRequest = FileOperationRequest(
            kind: .delete,
            sources: sources,
            permanentDelete: permanent
        )
        pendingDeletePermanent = permanent
        showDeleteConfirmation = true
    }

    func beginRename(_ item: FileItem) {
        renameTarget = item
        renameText = item.name
    }

    func beginBatchRename(urls: [URL]) {
        batchRenameURLs = urls
        batchRenameTemplate = "{name}_{counter}"
        batchRenameStartIndex = 1
        batchRenameSkipCollisions = true
        refreshBatchRenamePlan()
        showBatchRenameSheet = true
    }

    func refreshBatchRenamePlan() {
        batchRenamePlan = BatchRenameService.preview(
            urls: batchRenameURLs,
            template: batchRenameTemplate,
            startIndex: batchRenameStartIndex
        )
    }

    func confirmBatchRename() async -> Bool {
        guard let plan = batchRenamePlan else { return false }
        isRunning = true
        errorMessage = nil
        do {
            _ = try BatchRenameService.apply(plan, skipCollisions: batchRenameSkipCollisions)
            showBatchRenameSheet = false
            batchRenamePlan = nil
            batchRenameURLs = []
            isRunning = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isRunning = false
            return false
        }
    }

    func cancelActiveOperation() {
        runningTask?.cancel()
        isRunning = false
        progress?.isCancelled = true
        activeRequest = nil
        showCopyMoveSheet = false
    }

    func confirmCopyOrMove() async {
        guard let request = activeRequest,
              let destination = request.destination else { return }

        isRunning = true
        errorMessage = nil

        let policy = request.overwritePolicy
        let sources = request.sources
        let kind = request.kind

        runningTask = Task {
            do {
                let progressHandler: @Sendable (FileOperationProgress) -> Void = { [weak self] value in
                    Task { @MainActor in
                        self?.progress = value
                    }
                }

                switch kind {
                case .copy:
                    try await fileService.copyItems(
                        sources,
                        to: destination,
                        overwritePolicy: policy,
                        progress: progressHandler
                    )
                case .move:
                    try await fileService.moveItems(
                        sources,
                        to: destination,
                        overwritePolicy: policy,
                        progress: progressHandler
                    )
                default:
                    break
                }

                isRunning = false
                showCopyMoveSheet = false
                activeRequest = nil
                progress = nil
            } catch is CancellationError {
                isRunning = false
                errorMessage = FileOperationError.cancelled.errorDescription
            } catch {
                isRunning = false
                errorMessage = error.localizedDescription
            }
        }

        await runningTask?.value
    }

    func confirmDelete() async {
        guard let request = activeRequest else { return }
        isRunning = true
        errorMessage = nil

        do {
            if request.permanentDelete {
                try fileService.permanentlyDeleteItems(request.sources)
            } else {
                try fileService.trashItems(request.sources)
            }
            showDeleteConfirmation = false
            activeRequest = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isRunning = false
    }

    func confirmRename() async -> Bool {
        guard let target = renameTarget else { return false }
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != target.name else {
            renameTarget = nil
            return false
        }

        do {
            _ = try fileService.renameItem(at: target.url, to: newName)
            renameTarget = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func createFolder(in directory: URL, name: String) async -> Bool {
        let url = directory.appendingPathComponent(name)
        do {
            try fileService.createDirectory(at: url)
            showNewFolderSheet = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func createFile(in directory: URL, name: String) async -> Bool {
        let url = directory.appendingPathComponent(name)
        do {
            try fileService.createEmptyFile(at: url)
            showNewFileSheet = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func duplicate(_ items: [FileItem]) async -> Bool {
        do {
            for item in items where !item.isParentEntry {
                _ = try fileService.duplicateItem(at: item.url)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func createSymlink(from source: URL, in directory: URL) async -> Bool {
        let linkURL = directory.appendingPathComponent(source.lastPathComponent)
        do {
            try fileService.createSymbolicLink(at: linkURL, pointingTo: source)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func compress(_ items: [FileItem], into directory: URL) async -> Bool {
        guard !items.isEmpty else { return false }
        let name = items.count == 1
            ? items[0].url.deletingPathExtension().lastPathComponent + ".zip"
            : "Archive.zip"
        let destination = directory.appendingPathComponent(name)

        do {
            try fileService.compressItems(items.map(\.url), to: destination)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func extract(_ item: FileItem, into directory: URL) async -> Bool {
        do {
            try fileService.extractArchive(at: item.url, to: directory)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
