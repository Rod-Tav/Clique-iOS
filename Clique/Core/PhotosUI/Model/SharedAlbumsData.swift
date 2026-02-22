//
//  SharedAlbumsData.swift
//  Clique
//
//  Observable model for shared album state (iOS 26+).
//

import SwiftUI
import Photos

/// Scroll geometry snapshot used by grid views for prefetch calculations.
@available(iOS 26, *)
struct PhotosScrollInfo: Equatable {
    var offsetY: CGFloat
    var containerHeight: CGFloat
}

@available(iOS 26, *)
@Observable
class SharedAlbumsData {
    /// All shared albums with metadata
    var sharedAlbums: [(collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)] = []
    /// Deduplicated photos from all shared albums
    var allSharedAssets: [PHAsset] = []
    /// Loaded thumbnail images keyed by asset
    var thumbnailCache: [PHAsset: UIImage] = [:]
    /// Current photo library authorization status
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    /// True while loading photos for the Library tab
    var isLoadingPhotos: Bool = true
    /// True while loading albums for the Albums tab
    var isLoadingAlbums: Bool = true
    /// Efficient thumbnail loading manager
    let imageManager = PHCachingImageManager()

    /// Dynamic thumbnail size matching the 3-column grid cell dimensions
    var thumbnailSize: CGSize {
        let spacing: CGFloat = 2
        let totalSpacing = spacing * 2
        let cellSize = (UIScreen.width - totalSpacing) / 3
        let scale = UIScreen.main.scale
        let size = cellSize * min(scale, 2.0)
        return CGSize(width: size, height: size)
    }

    /// Thumbnail size for the 2-column album cover grid
    var albumThumbnailSize: CGSize {
        let spacing: CGFloat = 16
        let totalSpacing = spacing * 3 // padding left + gap + padding right
        let cellSize = (UIScreen.width - totalSpacing) / 2
        let scale = UIScreen.main.scale
        let size = cellSize * min(scale, 2.0)
        return CGSize(width: size, height: size)
    }

    /// Stops all in-flight caching requests on the image manager.
    func resetCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }

    /// Updates PHCachingImageManager prefetch window based on visible range.
    func updatePrefetching(visibleRange: Range<Int>) {
        let clamped = visibleRange.clamped(to: 0..<allSharedAssets.count)
        guard !clamped.isEmpty else { return }
        let assetsToCache = Array(allSharedAssets[clamped])
        imageManager.startCachingImages(for: assetsToCache, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
    }
}
