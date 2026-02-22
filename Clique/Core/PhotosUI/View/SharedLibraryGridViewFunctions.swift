//
//  SharedLibraryGridViewFunctions.swift
//  Clique
//
//  Logic companion: auth, fetch shared album photos, thumbnail loading.
//

import SwiftUI
import Photos

@available(iOS 26, *)
extension SharedLibraryGridView {
    /// Request photo library authorization, then fetch shared album photos.
    func checkPhotoAuthorization() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        sharedData.authorizationStatus = status

        switch status {
        case .authorized, .limited:
            fetchAllSharedAlbumPhotos()
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                sharedData.authorizationStatus = newStatus
                if newStatus == .authorized || newStatus == .limited {
                    fetchAllSharedAlbumPhotos()
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

    /// Fetch all photos from iCloud Shared Albums, deduplicate, sort by creation date desc.
    func fetchAllSharedAlbumPhotos() {
        let sharedAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumCloudShared,
            options: nil
        )

        var seenIdentifiers = Set<String>()
        var assets: [PHAsset] = []

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        sharedAlbums.enumerateObjects { collection, _, _ in
            let result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            result.enumerateObjects { asset, _, _ in
                if !seenIdentifiers.contains(asset.localIdentifier) {
                    seenIdentifiers.insert(asset.localIdentifier)
                    assets.append(asset)
                }
            }
        }

        // Sort all collected assets by creation date descending
        assets.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

        sharedData.allSharedAssets = assets
        sharedData.isLoadingPhotos = false
    }

    /// Compute the visible asset index range from scroll geometry and drive prefetching.
    func updatePrefetchRange(scrollOffset: CGFloat, containerHeight: CGFloat) {
        let rowHeight: CGFloat = 122 // 120 cell + 2 spacing
        let columns = 3
        let topRow = max(0, Int(scrollOffset / rowHeight))
        let visibleRows = Int(ceil(containerHeight / rowHeight)) + 1
        let firstIndex = topRow * columns
        let lastIndex = (topRow + visibleRows) * columns
        guard firstIndex < lastIndex else { return }
        sharedData.updatePrefetching(visibleRange: firstIndex..<lastIndex)
    }

    /// Load a thumbnail for a single asset into the shared cache.
    func loadThumbnail(for asset: PHAsset) {
        guard sharedData.thumbnailCache[asset] == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true // shared albums may need iCloud fetch
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
