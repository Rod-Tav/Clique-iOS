//
//  TabViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 7/11/25.
//

import Photos

@Observable final class TabViewModel {
    var successfulImages: Int = 0
    var totalImages: Int = 0
    
    var triggerNavToCollection: Bool = false
    
    var collectionId: String = ""
    
    var uploadFailed: Bool = false
    var retryImages: [PreparedImageVariant]? = nil
    var retryLivePhotoAssets: [(assetId: String, asset: PHAsset)?]? = nil
    var retryTranscodedVideoUrls: [URL?]? = nil
    var retryUrlItems: [Components.Schemas.UrlCollectionItem]? = nil
    var retryPhotoDatePairs: [Components.Schemas.PhotoVideoDate]? = nil
    var retryCollectionId: String? = nil
    
    func reset() {
        successfulImages = 0
        totalImages = retryImages == nil ? 0 : retryImages!.count
    }
    
    func resetRetry() {
        uploadFailed = false
        retryImages = nil
        retryLivePhotoAssets = nil
        retryTranscodedVideoUrls = nil
        retryUrlItems = nil
        retryPhotoDatePairs = nil
        retryCollectionId = nil
    }
    
    func uploadToCollection(
        makingNew: Bool,
        photoDatePairs: [Components.Schemas.PhotoVideoDate],
        preparedImages: [PreparedImageVariant],
        livePhotoAssets: [(assetId: String, asset: PHAsset)?],
        transcodedVideoUrls: [URL?],
        collection: ClCollection,
        _ collectionStore: CollectionStore,
        _ collectionImageStore: CollectionImageStore
    ) async throws {
        var collectionId: String
        
        if makingNew {
            let createdCollection = try await CollectionService.createCollection(.init(body: .json(.init(
                name: collection.name,
                description: collection.description,
                cliqueId: collection.cliqueId,
                privacySetting: mapFromVisibility(collection.visibility)
            ))))
            
            collectionId = createdCollection.collection!.collectionData!.collectionDataId!
        } else {
            collectionId = collection.id
        }

        // Log what we're sending to backend
        print("📤 Sending to backend:")
        print("   Collection ID: \(collectionId)")
        print("   Total items: \(photoDatePairs.count)")
        for (index, pair) in photoDatePairs.enumerated() {
            print("   [\(index)] mediaType: \(pair.mediaType?.rawValue ?? "nil"), hasPhoto: \(pair.photo != nil), hasVideo: \(pair.video != nil)")
            if let video = pair.video, let baseVideo = video.baseVideo {
                print("       Video - contentType: \(baseVideo.contentType ?? "nil"), size: \(baseVideo.contentLength ?? 0)")
            }
        }

        let collectionWithPutLinks = try await CollectionService.uploadPhotosToCollection(
            .init(body: .json(.init(collectionId: collectionId, photos: photoDatePairs)))
        )
        
        let urlItems = collectionWithPutLinks.collection!.collectionItems!

        // Only get original quality URL - backend handles quality conversion
        let urls: [String?] = urlItems.map { $0.urls?.url }

        // Extract video URLs for Live Photos
        let videoUrls: [String?] = urlItems.map { item in
            return item.videoUrls?.url // Only need the full resolution video URL
        }

        // Extract video content-types from photoDatePairs
        let videoContentTypes: [String?] = photoDatePairs.map { pair in
            return pair.video?.baseVideo?.contentType
        }

        print("🚀 Preparing Upload")
        print("📸 Total Images: \(preparedImages.count)")
        print("🔗 Total URLs: \(urls.compactMap { $0 }.count)")
        print("🎥 Video URLs: \(videoUrls.compactMap { $0 }.count)")

        // Debug: Print first URL to inspect structure
        if let firstUrl = urls.first {
            print("🔍 Upload URL: \(firstUrl ?? "nil")")
        }

        guard preparedImages.count == urls.count else {
            print("❌ Error: Mismatch between images and URL sets")
            return
        }

        var failedUploadIndices: [Int] = []

        await PhotoHelper.uploadImages(
            preparedImages: preparedImages,
            urls: urls,
            livePhotoAssets: livePhotoAssets,
            transcodedVideoUrls: transcodedVideoUrls,
            videoUrls: videoUrls,
            videoContentTypes: videoContentTypes,
            onProgress: { completed, total in
                self.successfulImages = completed
                self.totalImages = total
                print("✅ Upload \(completed)/\(total) complete")
            },
            failedUpload: { index, quality in
                print("❌ Failed upload at index \(index) for quality \(quality.rawValue)")
                if !failedUploadIndices.contains(index) {
                    failedUploadIndices.append(index)
                }
            },
            onCompletion: { success in
                if success {
                    Task {
                        print("✅ All images uploaded!")

                        // Trigger backend async processing (quality conversion, video processing, etc.)
                        let successfulItemIds = urlItems.compactMap { $0.collectionItem?.collectionItemId }
                        do {
                            try await CollectionService.markCollectionImagesAsUploaded(
                                .init(body: .json(.init(collectionItemIds: successfulItemIds, collectionId: collectionId)))
                            )
                            print("🎬 Backend processing started for \(successfulItemIds.count) items")
                        } catch {
                            print("⚠️ Failed to trigger backend processing: \(error)")
                            // Non-critical - processing will eventually happen via other mechanisms
                        }

                        self.reset()
                    }
                } else  {
                    // failure
                    self.uploadFailed = true
                    let retryImages = failedUploadIndices.map { preparedImages[$0] }
                    let retryAssets = failedUploadIndices.map { livePhotoAssets[$0] }
                    let retryVideos = failedUploadIndices.map { transcodedVideoUrls[$0] }
                    let retryUrlItems = failedUploadIndices.map { urlItems[$0] }
                    let retryPairs = failedUploadIndices.map { photoDatePairs[$0] }

                    self.retryImages = retryImages
                    self.retryLivePhotoAssets = retryAssets
                    self.retryTranscodedVideoUrls = retryVideos
                    self.retryUrlItems = retryUrlItems
                    self.retryPhotoDatePairs = retryPairs
                    self.retryCollectionId = collectionId
                    self.reset()
                }
            }
        )
        
        self.collectionId = collectionId
    }
    
    func retryUploadImages() async throws {
        guard let retryImages, let retryLivePhotoAssets, let retryTranscodedVideoUrls, let retryUrlItems, let retryPhotoDatePairs, let retryCollectionId else { return }

        var failedUploadIndices: [Int] = []

        // Only get original quality URL - backend handles quality conversion
        let urls: [String?] = retryUrlItems.map { $0.urls?.url }

        let videoUrls: [String?] = retryUrlItems.map { item in
            return item.videoUrls?.url
        }

        // Extract video content-types from retryPhotoDatePairs
        let videoContentTypes: [String?] = retryPhotoDatePairs.map { pair in
            return pair.video?.baseVideo?.contentType
        }

        self.uploadFailed = false

        await PhotoHelper.uploadImages(
            preparedImages: retryImages,
            urls: urls,
            livePhotoAssets: retryLivePhotoAssets,
            transcodedVideoUrls: retryTranscodedVideoUrls,
            videoUrls: videoUrls,
            videoContentTypes: videoContentTypes,
            onProgress: { completed, total in
                self.successfulImages = completed
                self.totalImages = total
                print("✅ Retry Upload \(completed)/\(total) complete")
            },
            failedUpload: { index, quality in
                print("❌ Retry failed at index \(index) for quality \(quality.rawValue)")
                if !failedUploadIndices.contains(index) {
                    failedUploadIndices.append(index)
                }
            },
            onCompletion: { success in
                if success {
                    Task {
                        print("✅ All retry images uploaded!")

                        // Trigger backend async processing for retry items
                        let successfulItemIds = retryUrlItems.compactMap { $0.collectionItem?.collectionItemId }
                        do {
                            try await CollectionService.markCollectionImagesAsUploaded(
                                .init(body: .json(.init(collectionItemIds: successfulItemIds, collectionId: retryCollectionId)))
                            )
                            print("🎬 Backend processing started for \(successfulItemIds.count) retry items")
                        } catch {
                            print("⚠️ Failed to trigger backend processing for retries: \(error)")
                            // Non-critical - processing will eventually happen via other mechanisms
                        }

                        self.resetRetry()
                        self.reset()
                    }
                } else {
                    let retryImages = failedUploadIndices.map { retryImages[$0] }
                    let retryAssets = failedUploadIndices.map { retryLivePhotoAssets[$0] }
                    let retryVideos = failedUploadIndices.map { retryTranscodedVideoUrls[$0] }
                    let retryUrlItems = failedUploadIndices.map { retryUrlItems[$0] }
                    let retryPairs = failedUploadIndices.map { retryPhotoDatePairs[$0] }

                    self.retryImages = retryImages
                    self.retryLivePhotoAssets = retryAssets
                    self.retryTranscodedVideoUrls = retryVideos
                    self.retryUrlItems = retryUrlItems
                    self.retryPhotoDatePairs = retryPairs
                    self.uploadFailed = true
                }
            }
        )
    }
}
