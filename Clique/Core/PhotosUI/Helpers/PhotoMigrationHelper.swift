//
//  PhotoMigrationHelper.swift
//  Clique
//
//  Handles migrating photos from Clique S3 backend to iCloud Photo Library.
//

import SwiftUI
import Photos

@available(iOS 26, *)
@Observable
class PhotoMigrationHelper {
    var migrationProgress: Double = 0
    var isMigrating: Bool = false
    var error: String?
    var migratedCount: Int = 0
    var totalCount: Int = 0

    /// Migrate all images from a Clique collection into the user's Photo Library,
    /// optionally adding them to a named album.
    func migrateCollection(_ collection: ClCollection, albumName: String? = nil) async {
        let imageItems = collection.images.filter { $0.imageUrl?.bestUrl != nil }
        guard !imageItems.isEmpty else {
            error = "No downloadable images in this collection."
            return
        }

        await MainActor.run {
            isMigrating = true
            error = nil
            migratedCount = 0
            totalCount = imageItems.count
            migrationProgress = 0
        }

        // Request photo library access
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                error = "Photo Library access denied. Please allow access in Settings."
                isMigrating = false
            }
            return
        }

        // Download all images
        var downloadedImages: [UIImage] = []
        for (index, item) in imageItems.enumerated() {
            guard let url = item.imageUrl?.bestUrl else { continue }

            do {
                let image = try await downloadImage(from: url)
                downloadedImages.append(image)
            } catch {
                print("DEBUG: Failed to download image \(index): \(error.localizedDescription)")
            }

            await MainActor.run {
                migratedCount = index + 1
                migrationProgress = Double(migratedCount) / Double(totalCount)
            }
        }

        guard !downloadedImages.isEmpty else {
            await MainActor.run {
                error = "Failed to download any images."
                isMigrating = false
            }
            return
        }

        // Save to Photo Library
        do {
            let name = albumName ?? collection.name
            try await saveToPhotoLibrary(images: downloadedImages, albumName: name)
        } catch {
            await MainActor.run {
                self.error = "Failed to save to Photos: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            migrationProgress = 1.0
            isMigrating = false
        }
    }

    /// Download a single image from a URL.
    func downloadImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        return image
    }

    /// Save an array of images to the Photo Library inside a named album.
    func saveToPhotoLibrary(images: [UIImage], albumName: String) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            // Find or create the album
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
            let existingAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .any,
                options: fetchOptions
            )

            let albumChangeRequest: PHAssetCollectionChangeRequest
            if let existing = existingAlbums.firstObject {
                guard let changeRequest = PHAssetCollectionChangeRequest(for: existing) else { return }
                albumChangeRequest = changeRequest
            } else {
                albumChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            }

            // Create asset requests and add to album
            var assetPlaceholders: [PHObjectPlaceholder] = []
            for image in images {
                let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let placeholder = assetRequest.placeholderForCreatedAsset {
                    assetPlaceholders.append(placeholder)
                }
            }

            albumChangeRequest.addAssets(assetPlaceholders as NSArray)
        }
    }
}
