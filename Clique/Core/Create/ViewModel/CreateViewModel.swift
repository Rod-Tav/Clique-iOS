//
//  CreateViewModel.swift
//  Clique
//
//  Created by Rod Tavangar on 3/11/25.
//

import SwiftUI
import PhotosUI
import Photos

enum CreateFlowDestination: Hashable {
    case reviewPhotos, album(assetCollection: PHAssetCollection, title: String)
}

@Observable final class CreateViewModel {
    var selectedCollectionId: String?
    var selectedCollectionClique: Clique?
    
    var capturedUIImage: UIImage?
    var newCollectionName: String = ""
    var newCollectionCaption: String = ""
    var newCollectionVisibility: Visibility = .followers
    var newCollectionClique: Clique?
    
    var showNewCollectionSheet: Bool = false
    var fromLibrary: Bool = false
    
    var selectedImages: [UIImage] = []
    var selectedImagesDates: [Date] = []
    var selectedImagesTimezoneOffsets: [String?] = []  // Timezone offsets for each photo (e.g., "-0400", "+0530")

    /// Primary photo selection storage (unordered Set for O(1) operations)
    ///
    /// **Important**: This Set is the source of truth for which photos are selected.
    /// Use this for:
    /// - Fast O(1) contains/insert/remove during selection
    /// - Checking if a photo is selected (grid visual state)
    /// - Counting total selected photos
    ///
    /// **Relationship with orderedSelectedAssets**:
    /// - `selectedAssets` = Set (unordered, fast lookups)
    /// - `orderedSelectedAssets` = Array (sorted by creation date)
    /// - Both must always contain the same PHAssets (verified by debug assertion)
    /// - `orderedSelectedAssets` is populated lazily in SelectedPhotosView
    ///
    /// **Synchronization**: When modifying selections, only update `selectedAssets`.
    /// The ordered array is regenerated on-demand when needed for display.
    var selectedAssets: Set<PHAsset> = []

    /// Sorted array of selected photos (populated on-demand by SelectedPhotosView)
    ///
    /// **Purpose**: Display photos in chronological library order (sorted by creation date)
    ///
    /// **Lifecycle**:
    /// 1. During selection: Remains empty (no overhead)
    /// 2. When SelectedPhotosView appears: Populated via async sort of `selectedAssets`
    /// 3. After removal/clear: Cleaned up along with `selectedAssets`
    ///
    /// **Important**: Do NOT modify directly during selection.
    /// This array is regenerated from `selectedAssets` when needed.
    ///
    /// **Invariant**: `selectedAssets.count == orderedSelectedAssets.count` (when populated)
    var orderedSelectedAssets: [PHAsset] = []

    var processedAssets: Set<PHAsset> = []
    // Maps PHAsset identifiers to their processed image, date, and timezone offset
    var processedImageData: [String: (image: UIImage, date: Date, timezoneOffset: String?)] = [:]
    // Tracks which assets are Live Photos (by localIdentifier)
    var livePhotoAssets: Set<String> = []
    // Tracks Live Photo extraction errors (by asset localIdentifier)
    var livePhotoExtractionErrors: [String: Error] = [:]
    /// Prepared upload metadata
    var photoDatePairs: [Components.Schemas.PhotoVideoDate] = []
    /// Prepared image variants for upload (original quality only - backend handles quality conversion)
    var preparedImageVariants: [PreparedImageVariant] = []
    /// Asset references for Live Photos (parallel to preparedImageVariants, nil for regular photos)
    /// Stores (assetId, asset) tuples to enable just-in-time video extraction during upload
    var livePhotoAssetReferences: [(assetId: String, asset: PHAsset)?] = []
    /// Pre-transcoded video URLs (parallel to preparedImageVariants, nil for regular photos)
    /// Videos are transcoded during processing to get accurate file sizes for presigned URL generation
    var transcodedVideoUrls: [URL?] = []
    /// Asset identifiers for ALL photos (parallel to preparedImageVariants)
    /// Used for caching device photos to show during PENDING upload status
    var allAssetIdentifiers: [String?] = []

    var collectionToGoTo: ClCollection?

    /// Flag to coordinate photo processing between NewCollectionDetailsView and SelectedPhotosView.
    ///
    /// **Why this exists**: SelectedPhotosView is presented as a fullScreenCover (not a NavigationDestination).
    /// Unlike NavigationDestination which auto-dismisses when NavigationPath is cleared, fullScreenCover
    /// requires manual dismissal coordination.
    ///
    /// **Flow**:
    /// 1. User taps upload in NewCollectionDetailsView → sets this flag to true
    /// 2. SelectedPhotosView's onChange detects the flag
    /// 3. SelectedPhotosView processes photos (PHAssets → UIImages → upload variants)
    /// 4. SelectedPhotosView dismisses itself
    /// 5. Upload proceeds with processed data
    ///
    /// This pattern ensures photo processing happens in SelectedPhotosView where the processing UI lives,
    /// while maintaining the simple upload logic in NewCollectionDetailsView.
    var shouldProcessAndUploadForNewCollection: Bool = false

    @MainActor func startUpload(_ userStore: UserStore, _ tabViewCoordinator: TabViewCoordinator, skipProcessing: Bool = false) {
        guard let cuid = userStore.currentUserId else { return }

        // Process photos for upload first (unless already done)
        Task {
            if !skipProcessing {
                await PhotoProcessingHelper.processSelectedPhotosForUpload(viewModel: self)
            }

            tabViewCoordinator.profileNavigationPath = NavigationPath()
            tabViewCoordinator.activeTab = tabViewCoordinator.previousTab
            tabViewCoordinator.showTabBar = true
            
            var flicks = [CollectionImage]()
            if let capturedUIImage = capturedUIImage {
                flicks.append(CollectionImage(id: UUID().uuidString, owner: userStore.currentUser, uiImage: capturedUIImage, date: Date()))
            } else {
                flicks = zip(selectedImages, selectedImagesDates)
                    .map { image, date in
                        CollectionImage(id: UUID().uuidString, owner: userStore.currentUser, uiImage: image, date: date)
                    }
            }
            
            let collection = collectionToGoTo ?? getCollectionObj(cuid: cuid, flicks: flicks)
            let makingNew = collectionToGoTo == nil


            NotificationCenter.default.post(name: .showProcessingImagesForUpload, object: nil)


            NotificationCenter.default.post(
                name: .uploadImagesToCollection,
                object: nil,
                userInfo: [
                    "makingNew": makingNew,
                    "collection": collection,
                    "photoDatePairs": photoDatePairs,
                    "variants": preparedImageVariants,
                    "livePhotoAssets": livePhotoAssetReferences,
                    "transcodedVideoUrls": transcodedVideoUrls,
                    "allAssetIdentifiers": allAssetIdentifiers
                ]
            )
           
            trigger(.cameraReset)
            
            reset()
        }
    }
    
    func getCollectionObj(cuid: String, flicks: [CollectionImage]) -> ClCollection {
        // Set numFlicks to 0 for new collections - backend will set the correct count after processing
        // This prevents double-counting with pending uploads in displayFlickCount()
        return ClCollection(id: UUID().uuidString, name: newCollectionName.trim(), description: newCollectionCaption.trim(), userId: cuid, cliqueId: newCollectionClique!.id, creation: Date(), images: flicks, visibility: newCollectionVisibility, numFlicks: 0)
    }
    
    func removeAsset(_ asset: PHAsset) {
        // Remove from selected assets
        selectedAssets.remove(asset)
        orderedSelectedAssets.removeAll { $0 == asset }

        // If it was processed, remove it from all collections
        if processedAssets.contains(asset),
           let imageData = processedImageData[asset.localIdentifier] {

            // Find and remove from arrays
            if let index = selectedImages.firstIndex(where: { $0 === imageData.image }) {
                selectedImages.remove(at: index)
                // Remove corresponding date at same index
                if index < selectedImagesDates.count {
                    selectedImagesDates.remove(at: index)
                }
            }

            // Clean up tracking data
            processedAssets.remove(asset)
            processedImageData.removeValue(forKey: asset.localIdentifier)
            livePhotoAssets.remove(asset.localIdentifier)
        }
    }
    
    /// Add processed assets - handles both single and multiple assets efficiently
    func addProcessedAssets(_ assets: [(asset: PHAsset, image: UIImage, date: Date, timezoneOffset: String?)]) {
        // Process each asset and directly append to arrays
        for item in assets {
            // Skip if already processed
            guard !processedAssets.contains(item.asset) else { continue }

            // Update tracking sets/dictionaries
            processedAssets.insert(item.asset)
            processedImageData[item.asset.localIdentifier] = (image: item.image, date: item.date, timezoneOffset: item.timezoneOffset)

            // Directly append to arrays - no rebuild needed!
            selectedImages.append(item.image)
            selectedImagesDates.append(item.date)
            selectedImagesTimezoneOffsets.append(item.timezoneOffset)
        }
    }

    /// Clear all selected photos and processed data
    func clearAllSelections() {
        selectedAssets.removeAll()
        orderedSelectedAssets.removeAll()
        selectedImages.removeAll()
        selectedImagesDates.removeAll()
        selectedImagesTimezoneOffsets.removeAll()
        processedAssets.removeAll()
        processedImageData.removeAll()
        livePhotoAssets.removeAll()
        livePhotoExtractionErrors.removeAll()
    }

    func reset() {
        selectedCollectionId = nil
        selectedCollectionClique = nil
        
        capturedUIImage = nil
        newCollectionName  = ""
        newCollectionCaption = ""
        newCollectionVisibility = .followers
        newCollectionClique = nil
        
        showNewCollectionSheet = false
        fromLibrary = false
        
        selectedImages = []
        selectedImagesDates = []
        selectedImagesTimezoneOffsets = []
        selectedAssets = []
        orderedSelectedAssets = []
        processedAssets = []
        processedImageData = [:]
        livePhotoAssets = []
        livePhotoExtractionErrors = [:]
        photoDatePairs = []
        preparedImageVariants = []
        livePhotoAssetReferences = []
        transcodedVideoUrls = []
        allAssetIdentifiers = []

        collectionToGoTo = nil
        shouldProcessAndUploadForNewCollection = false
    }

    /// Check if an asset is a Live Photo
    func isLivePhoto(_ asset: PHAsset) -> Bool {
        return livePhotoAssets.contains(asset.localIdentifier)
    }
}
