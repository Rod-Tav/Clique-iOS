//
//  CollectionImageSaveHelpers.swift
//  Clique
//
//  Created by Assistant on shared save/delete helpers.
//

import Foundation
import Toasts

/// Shared helper functions for saving and deleting collection images
/// Used by CollectionDetailView and FlicksFeedView to reduce code duplication
struct CollectionImageSaveHelpers {

    /// Handles saving a Live Photo with metadata injection
    /// - Parameters:
    ///   - image: The collection image to save
    ///   - collectionImageStore: Store for accessing cached timezone data
    ///   - isSavingLivePhoto: Binding to track save state
    ///   - presentToast: Toast presentation closure
    static func saveLivePhoto(
        image: CollectionImage,
        collectionImageStore: CollectionImageStore,
        isSavingLivePhoto: inout Bool,
        presentToast: @escaping (Toast) -> Void
    ) async {
        guard let imageUrl = image.imageUrl?.highQualityUrl,
              let videoUrl = image.videoUrls?.highQualityUrl else { return }

        let date = image.date
        var timezoneOffset = image.cachedTimezoneOffset

        // Check store cache (timezone may have been extracted during display)
        if timezoneOffset == nil {
            timezoneOffset = collectionImageStore.getCachedTimezoneOffset(for: image.id)
            print("📅 [SAVE] Checked store cache: \(timezoneOffset ?? "nil")")
        }

        // For old photos without cached timezone, try to extract from video metadata
        if timezoneOffset == nil, let videoURL = URL(string: videoUrl) {
            timezoneOffset = await VideoMetadataHelper.extractTimezoneOffset(from: videoURL)
            print("📅 [SAVE-FALLBACK] Extracted timezone from video: \(timezoneOffset ?? "nil")")
        }

        if timezoneOffset == nil {
            print("⚠️ [SAVE] No timezone information available for this photo")
            print("   This is an old photo uploaded before timezone preservation was implemented")
            print("   It will be saved in the device's current timezone")
        }

        isSavingLivePhoto = true

        let saver = LivePhotoSaver()
        let success = await saver.saveLivePhoto(
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            date: date,
            timezoneOffset: timezoneOffset
        ) { progress in
            switch progress {
            case .downloading:
                presentToast(Toasts.savingLivePhoto)
            case .processing, .saving:
                // Don't show additional toasts, initial toast still showing
                break
            case .completed:
                presentToast(Toasts.savedLivePhoto)
                isSavingLivePhoto = false
            case .failed:
                // Fallback already happened, show video saved toast
                presentToast(Toasts.savedVideo)
                isSavingLivePhoto = false
            }
        }

        if !success && !isSavingLivePhoto {
            presentToast(Toasts.somethingWentWrong)
        }
    }

    /// Handles saving a standalone video
    /// - Parameters:
    ///   - image: The collection image to save
    ///   - presentToast: Toast presentation closure
    static func saveVideo(
        image: CollectionImage,
        presentToast: @escaping (Toast) -> Void
    ) async {
        guard let videoUrl = image.videoUrls?.highQualityUrl else { return }

        let date = image.date
        let timezoneOffset = image.cachedTimezoneOffset

        do {
            // Download video
            let videoLocalUrl = try await VideoCache.shared.getVideo(from: URL(string: videoUrl)!)

            // Save video
            let imageSaver = ImageSaver()
            imageSaver.writeVideoToPhotoAlbum(videoUrl: videoLocalUrl, date: date, timezoneOffset: timezoneOffset) { success in
                presentToast(success ? Toasts.savedVideo : Toasts.somethingWentWrong)
            }
        } catch {
            print("❌ Failed to save video: \(error)")
            presentToast(Toasts.somethingWentWrong)
        }
    }

    /// Handles saving a static image
    /// - Parameters:
    ///   - image: The collection image to save
    ///   - presentToast: Toast presentation closure
    static func saveImage(
        image: CollectionImage,
        presentToast: @escaping (Toast) -> Void
    ) async {
        guard let imageUrl = image.imageUrl,
              let url = imageUrl.highQualityUrl,
              let loadedImage = await fetchImageWithKingfisher(from: url) else { return }

        let imageSaver = ImageSaver()
        imageSaver.writeToPhotoAlbum(image: loadedImage, date: image.date, timezoneOffset: image.cachedTimezoneOffset) { success in
            presentToast(success ? Toasts.savedImage : Toasts.somethingWentWrong)
        }
    }

    /// Handles deleting a collection item (flick)
    /// - Parameters:
    ///   - imageId: ID of the image to delete
    ///   - collectionId: ID of the collection containing the image
    ///   - collectionStore: Collection store for updating state
    ///   - collectionImageStore: Image store for updating state
    ///   - presentToast: Toast presentation closure
    ///   - onSuccess: Optional closure called after successful deletion
    static func deleteCollectionItem(
        imageId: String,
        collectionId: String,
        collectionStore: CollectionStore,
        collectionImageStore: CollectionImageStore,
        presentToast: @escaping (Toast) -> Void,
        onSuccess: (() -> Void)? = nil
    ) async {
        do {
            try await CollectionService.deleteCollectionItem(.init(path: .init(collectionItemId: imageId)))

            collectionStore.collections[collectionId]?.images.removeAll(where: { $0.id == imageId })
            collectionStore.collections[collectionId]?.numFlicks -= 1
            collectionImageStore.images.removeValue(forKey: imageId)

            trigger(.refreshCollectionCells, object: [collectionId])

            onSuccess?()
        } catch {
            presentToast(Toasts.somethingWentWrong)
        }
    }
}
