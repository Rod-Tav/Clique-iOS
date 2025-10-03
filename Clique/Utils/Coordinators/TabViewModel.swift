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
    var retryImages: [(high: PreparedImageVariant, med: PreparedImageVariant, low: PreparedImageVariant)]? = nil
    var retryLivePhotoAssets: [(assetId: String, asset: PHAsset)?]? = nil
    var retryUrlItems: [Components.Schemas.UrlCollectionItem]? = nil
    var retryCollectionId: String? = nil
    
    func reset() {
        successfulImages = 0
        totalImages = retryImages == nil ? 0 : retryImages!.count
    }
    
    func resetRetry() {
        uploadFailed = false
        retryImages = nil
        retryLivePhotoAssets = nil
        retryUrlItems = nil
        retryCollectionId = nil
    }
    
    func uploadToCollection(
        makingNew: Bool,
        photoDatePairs: [Components.Schemas.PhotoVideoDate],
        preparedImages: [(high: PreparedImageVariant, med: PreparedImageVariant, low: PreparedImageVariant)],
        livePhotoAssets: [(assetId: String, asset: PHAsset)?],
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
     
        let collectionWithPutLinks = try await CollectionService.uploadPhotosToCollection(
            .init(body: .json(.init(collectionId: collectionId, photos: photoDatePairs)))
        )
        
        let urlItems = collectionWithPutLinks.collection!.collectionItems!

        let urls: [(high: String?, med: String?, low: String?)] = urlItems.compactMap {
            guard let urls = $0.urls else { return nil }
            return (urls.url, urls.medQualityUrl, urls.lowQualityUrl)
        }

        // Extract video URLs for Live Photos
        let videoUrls: [String?] = urlItems.map { item in
            return item.videoUrls?.url // Only need the full resolution video URL
        }

        print("🚀 Preparing Upload")
        print("📸 Total Images: \(preparedImages.count)")
        print("🔗 Total URL Sets: \(urls.count)")
        print("🎥 Video URLs: \(videoUrls.compactMap { $0 }.count)")

        guard preparedImages.count == urls.count else {
            print("❌ Error: Mismatch between images and URL sets")
            return
        }

        var failedUploadIndices: [Int] = []

        await PhotoHelper.uploadImages(
            preparedImages: preparedImages,
            urls: urls,
            livePhotoAssets: livePhotoAssets,
            videoUrls: videoUrls,
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
                        let successfulCollectionItemIds = urlItems
                            .enumerated()
                            .filter { !failedUploadIndices.contains($0.offset) }
                            .compactMap { $0.element.collectionItem?.collectionItemId }
                        
                        if !successfulCollectionItemIds.isEmpty {
                            try await CollectionService.markCollectionImagesAsUploaded(
                                .init(body: .json(.init(collectionItemIds: successfulCollectionItemIds, collectionId: collectionId)))
                            )
                            print("✅ All images uploaded!")
                            self.reset()
                        }
                    }
                } else  {
                    // failure
                    self.uploadFailed = true
                    let retryImages = failedUploadIndices.map { preparedImages[$0] }
                    let retryAssets = failedUploadIndices.map { livePhotoAssets[$0] }
                    let retryUrlItems = failedUploadIndices.map { urlItems[$0] }

                    self.retryImages = retryImages
                    self.retryLivePhotoAssets = retryAssets
                    self.retryUrlItems = retryUrlItems
                    self.retryCollectionId = collectionId
                    self.reset()
                }
            }
        )
        
        self.collectionId = collectionId
    }
    
    func retryUploadImages() async throws {
        guard let retryImages, let retryLivePhotoAssets, let retryUrlItems, let retryCollectionId else { return }

        var failedUploadIndices: [Int] = []

        let urls: [(high: String?, med: String?, low: String?)] = retryUrlItems.compactMap {
            guard let urls = $0.urls else { return nil }
            return (urls.url, urls.medQualityUrl, urls.lowQualityUrl)
        }

        let videoUrls: [String?] = retryUrlItems.map { item in
            return item.videoUrls?.url
        }

        self.uploadFailed = false

        await PhotoHelper.uploadImages(
            preparedImages: retryImages,
            urls: urls,
            livePhotoAssets: retryLivePhotoAssets,
            videoUrls: videoUrls,
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
                        let successfulCollectionItemIds = retryUrlItems
                            .enumerated()
                            .filter { !failedUploadIndices.contains($0.offset) }
                            .compactMap { $0.element.collectionItem?.collectionItemId }
                        
                        if !successfulCollectionItemIds.isEmpty {
                            try await CollectionService.markCollectionImagesAsUploaded(
                                .init(body: .json(.init(collectionItemIds: successfulCollectionItemIds, collectionId: retryCollectionId)))
                            )
                            print("✅ All retry images uploaded!")
                        }
                        
                        self.resetRetry()
                        self.reset()
                    }
                } else {
                    let retryImages = failedUploadIndices.map { retryImages[$0] }
                    let retryAssets = failedUploadIndices.map { retryLivePhotoAssets[$0] }
                    let retryUrlItems = failedUploadIndices.map { retryUrlItems[$0] }

                    self.retryImages = retryImages
                    self.retryLivePhotoAssets = retryAssets
                    self.retryUrlItems = retryUrlItems
                    self.uploadFailed = true
                }
            }
        )
    }
}
