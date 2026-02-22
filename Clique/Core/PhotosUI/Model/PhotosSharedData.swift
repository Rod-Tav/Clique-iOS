//
//  PhotosSharedData.swift
//  Clique
//
//  Adapted from iOS18PhotosAppUI by Balaji Venkatesh
//

import SwiftUI
import Photos

@Observable
class PhotosSharedData {
    /// Used to create a custom paging indicator below the photos scroll view
    var activePage: Int = 1
    /// True when the photos grid scroll view is expanded
    var isExpanded: Bool = false
    /// Main scroll view offset
    var mainOffset: CGFloat = 0
    /// Photos grid scroll offset
    var photosScrollOffset: CGFloat = 0
    /// Selected time category (Years, Month, All)
    var selectedCategory: String = "Years"
    var allowsInteraction: Bool = true
    /// Drag condition flags for expanding/minimising the photos scroll view
    var canPullUp: Bool = false
    var canPullDown: Bool = false
    /// Expansion progress (0 = minimised, 1 = expanded)
    var progress: CGFloat = 0

    // MARK: - Photo Library State

    /// Current photo library authorization status
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    /// True while loading photos from the device library
    var isLoadingPhotos: Bool = true
    /// All device library photo assets
    var allAssets: [PHAsset] = []
    /// Loaded thumbnail images keyed by asset
    var thumbnailCache: [PHAsset: UIImage] = [:]
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
}
