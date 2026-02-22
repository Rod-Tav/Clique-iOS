//
//  PhotosGridScrollViewFunctions.swift
//  Clique
//
//  Logic companion file for PhotosGridScrollView.
//

import SwiftUI
import Photos

extension PhotosGridScrollView {
    /// Request photo library authorization if not yet determined, then load photos.
    func checkPhotoAuthorization() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        sharedData.authorizationStatus = status

        switch status {
        case .authorized, .limited:
            loadAllPhotos()
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                sharedData.authorizationStatus = newStatus
                if newStatus == .authorized || newStatus == .limited {
                    loadAllPhotos()
                } else {
                    sharedData.isLoadingPhotos = false
                }
            }
        default:
            await MainActor.run {
                sharedData.isLoadingPhotos = false
            }
        }
    }

    /// Fetch all image assets from the device library sorted by creation date descending.
    func loadAllPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )

        let result = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        sharedData.allAssets = assets
        sharedData.isLoadingPhotos = false
    }

    /// Load a thumbnail for a single asset into the shared cache.
    func loadThumbnail(for asset: PHAsset) {
        guard sharedData.thumbnailCache[asset] == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast

        sharedData.imageManager.requestImage(
            for: asset,
            targetSize: sharedData.thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image {
                DispatchQueue.main.async {
                    self.sharedData.thumbnailCache[asset] = image
                }
            }
        }
    }
}
