//
//  BatchExportHelper.swift
//  Clique
//
//  Exports all collection flicks to a local Photos album, handling photos, videos,
//  and Live Photos with concurrency-limited downloads.
//

import SwiftUI
import Photos

@available(iOS 26, *)
@Observable
class BatchExportHelper {
    var isExporting: Bool = false
    var exportProgress: Double = 0
    var exportedCount: Int = 0
    var totalCount: Int = 0
    var error: String?

    private let maxConcurrency = 3

    // MARK: - Public API

    /// Exports all items in the collection to a Photos album.
    /// Continues on per-item failures and reports the final count.
    func exportCollection(_ images: [CollectionImage], albumName: String) async {
        let exportable = images.filter { item in
            switch item.mediaType {
            case .PHOTO, .LIVE:
                return item.imageUrl?.bestUrl != nil
            case .VIDEO:
                return item.videoUrls?.bestUrl != nil
            }
        }

        guard !exportable.isEmpty else {
            error = "No downloadable media in this collection."
            return
        }

        await MainActor.run {
            isExporting = true
            error = nil
            exportedCount = 0
            totalCount = exportable.count
            exportProgress = 0
        }

        // Request photo library access
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                error = "Photo Library access denied. Please allow access in Settings."
                isExporting = false
            }
            return
        }

        // Find or create the target album
        let albumId: String?
        do {
            albumId = try await findOrCreateAlbum(named: albumName)
        } catch {
            await MainActor.run {
                self.error = "Failed to create album: \(error.localizedDescription)"
                isExporting = false
            }
            return
        }

        guard let albumId else {
            await MainActor.run {
                self.error = "Failed to create album."
                isExporting = false
            }
            return
        }

        // Export items with limited concurrency
        var successCount = 0
        var completed = 0

        await withTaskGroup(of: Bool.self) { group in
            var iterator = exportable.makeIterator()
            var running = 0

            // Seed the group with initial tasks
            while running < maxConcurrency, let item = iterator.next() {
                group.addTask { await self.exportItem(item, toAlbumId: albumId) }
                running += 1
            }

            // Process results and add new tasks
            for await success in group {
                completed += 1
                if success { successCount += 1 }

                await MainActor.run {
                    exportedCount = completed
                    exportProgress = Double(completed) / Double(exportable.count)
                }

                if let item = iterator.next() {
                    group.addTask { await self.exportItem(item, toAlbumId: albumId) }
                }
            }
        }

        await MainActor.run {
            exportProgress = 1.0
            isExporting = false
            if successCount < exportable.count {
                error = "Exported \(successCount) of \(exportable.count) items."
            }
        }
    }

    // MARK: - Private Helpers

    private func exportItem(_ item: CollectionImage, toAlbumId albumId: String) async -> Bool {
        switch item.mediaType {
        case .PHOTO:
            return await exportPhoto(item, toAlbumId: albumId)
        case .VIDEO:
            return await exportVideo(item, toAlbumId: albumId)
        case .LIVE:
            return await exportLivePhoto(item, toAlbumId: albumId)
        }
    }

    // MARK: Photo

    private func exportPhoto(_ item: CollectionImage, toAlbumId albumId: String) async -> Bool {
        guard let url = item.imageUrl?.bestUrl else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                return false
            }

            try await addAssetToAlbum(albumId: albumId) { request in
                request.addResource(with: .photo, data: image.jpegData(compressionQuality: 1.0) ?? data, options: nil)
                request.creationDate = item.date
            }
            return true
        } catch {
            print("DEBUG: Failed to export photo \(item.id): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Video

    private func exportVideo(_ item: CollectionImage, toAlbumId albumId: String) async -> Bool {
        guard let url = item.videoUrls?.bestUrl else { return false }

        do {
            let localURL = try await VideoCache.shared.getVideo(from: url)

            try await addAssetToAlbum(albumId: albumId) { request in
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                request.addResource(with: .video, fileURL: localURL, options: options)
                request.creationDate = item.date
            }
            return true
        } catch {
            print("DEBUG: Failed to export video \(item.id): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Live Photo

    private func exportLivePhoto(_ item: CollectionImage, toAlbumId albumId: String) async -> Bool {
        guard let imageUrl = item.imageUrl?.bestUrl,
              let videoUrl = item.videoUrls?.bestUrl else { return false }

        let saver = LivePhotoSaver()
        let success = await saver.saveLivePhoto(
            imageUrl: imageUrl.absoluteString,
            videoUrl: videoUrl.absoluteString,
            date: item.date,
            timezoneOffset: item.cachedTimezoneOffset,
            progressHandler: nil
        )
        // LivePhotoSaver saves directly to the library (not to a specific album).
        // For album placement we'd need the asset's localIdentifier after save,
        // which LivePhotoSaver doesn't return. Accept the trade-off for now.
        return success
    }

    // MARK: Album Helpers

    private func findOrCreateAlbum(named title: String) async throws -> String? {
        // Check for existing album
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", title)
        let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        if let album = existing.firstObject {
            return album.localIdentifier
        }

        // Create new album
        var placeholderId: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            placeholderId = request.placeholderForCreatedAssetCollection.localIdentifier
        }
        return placeholderId
    }

    private func addAssetToAlbum(
        albumId: String,
        configure: @escaping (PHAssetCreationRequest) -> Void
    ) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            configure(creationRequest)

            guard let placeholder = creationRequest.placeholderForCreatedAsset else { return }

            let albums = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [albumId],
                options: nil
            )
            guard let album = albums.firstObject,
                  let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else { return }

            albumChangeRequest.addAssets([placeholder] as NSArray)
        }
    }
}
