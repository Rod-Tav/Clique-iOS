//
//  RecentPhotosFunctions.swift
//  Clique
//
//  Logic companion file for RecentPhotosSection.
//

import Foundation
import Photos

extension RecentPhotosSection {
    /// Fetch recent non-screenshot photos from the device library.
    ///
    /// Excludes screenshots using the mediaSubtypes bitmask (512 = screenshots).
    /// Fetches up to 30 images sorted by creation date descending.
    internal func loadRecentPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 30
        // mediaType == 1 is .image; mediaSubtypes bitmask 512 is screenshots
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d AND NOT ((mediaSubtypes & %d) != 0)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        let result = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        recentAssets = assets
        isLoading = false
    }

    /// Request photo library authorization if not yet determined, then load photos.
    internal func checkPhotoAuthorization() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status

        switch status {
        case .authorized, .limited:
            loadRecentPhotos()
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                authorizationStatus = newStatus
                if newStatus == .authorized || newStatus == .limited {
                    loadRecentPhotos()
                } else {
                    isLoading = false
                }
            }
        default:
            await MainActor.run {
                isLoading = false
            }
        }
    }

    /// Stores selected assets on the coordinator and navigates to the Create tab in library mode.
    internal func navigateToCreateFlow() {
        tabViewCoordinator.pendingSelectedAssets = Array(selectedAssets)
        tabViewCoordinator.createFlowMode = .library
        tabViewCoordinator.selectTab(.create)
    }
}
