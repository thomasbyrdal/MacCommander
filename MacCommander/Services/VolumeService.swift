//
//  VolumeService.swift
//  MacCommander
//

import Foundation

struct VolumeInfo: Identifiable, Hashable, Sendable {
    let id: URL
    let name: String
    let url: URL
    let isRemovable: Bool
    let isEjectable: Bool
    let isNetwork: Bool
}

nonisolated struct VolumeService: Sendable {
    init() {}

    func mountedVolumes() -> [VolumeInfo] {
        let fileManager = FileManager.default
        let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [
                .volumeNameKey,
                .volumeIsRemovableKey,
                .volumeIsEjectableKey,
                .volumeIsLocalKey
            ],
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeIsRemovableKey,
                .volumeIsEjectableKey,
                .volumeIsLocalKey
            ])
            let name = values?.volumeName ?? url.lastPathComponent
            let isLocal = values?.volumeIsLocal ?? true
            return VolumeInfo(
                id: url,
                name: name,
                url: url,
                isRemovable: values?.volumeIsRemovable ?? false,
                isEjectable: values?.volumeIsEjectable ?? false,
                isNetwork: !isLocal
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
