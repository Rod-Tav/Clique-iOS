//
//  DeviceImageView.swift
//  Clique
//
//  Created by Assistant on device image view implementation.
//

import SwiftUI
import Photos

/// Displays a device photo for a PENDING collection item
///
/// This view checks the PendingImageCache for a mapping between collection item ID
/// and device PHAsset identifier. If found and not expired, it loads and displays
/// the photo from the user's device Photos library using existing components.
///
/// ## Usage
/// ```swift
/// DeviceImageView(itemId: "collection-item-123")
/// ```
///
/// ## Features
/// - Automatic cache lookup and expiration checking
/// - Delegates to existing display components based on media type:
///   - **TwoStageImageLoader** for photos
///   - **LivePhotoPreviewView** for Live Photos
///   - **VideoPreviewView** for videos
/// - Graceful fallback if asset deleted or cache expired
/// - Performance optimized with minimal code duplication
///
/// - Note: Shows placeholder if cache miss or asset not found (e.g., photo deleted or viewing on different device)
struct DeviceImageView: View {
    /// The collection item ID to look up in cache
    let itemId: String
    /// Optional width for sizing calculations
    let width: CGFloat?

    @State private var asset: PHAsset?
    @State private var mediaType: MediaType?
    @State private var isLoading: Bool = true

    var body: some View {
        Group {
            if let asset = asset, let mediaType = mediaType {
                // Display using appropriate existing component based on media type
                switch mediaType {
                case .PHOTO:
                    TwoStageImageLoader(
                        asset: asset,
                        thumbnail: nil,
                        contentMode: .fill
                    )
                    .if(width != nil) { view in
                        view.frame(width: width!, height: width!)
                    }

                case .LIVE:
                    LivePhotoPreviewView(
                        asset: asset,
                        thumbnail: nil,
                        contentMode: .fill
                    )
                    .if(width != nil) { view in
                        view.frame(width: width!, height: width!)
                    }

                case .VIDEO:
                    VideoPreviewView(
                        asset: asset,
                        thumbnail: nil,
                        contentMode: .fill
                    )
                    .if(width != nil) { view in
                        view.frame(width: width!, height: width!)
                    }
                }
            } else {
                // Loading or cache miss placeholder
                Rectangle()
                    .fill(Color.theme.iconTertiary)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    }
                    .if(width != nil) { view in
                        view.frame(width: width!, height: width!)
                    }
            }
        }
        .task {
            await loadAsset()
        }
    }

    /// Load PHAsset from cache
    @MainActor
    private func loadAsset() async {
        isLoading = true

        // Check cache for asset info
        guard let cachedInfo = PendingImageCache.shared.get(itemId) else {
            print("⚠️ [DEVICE-IMAGE] No cache entry for itemId: \(itemId)")
            isLoading = false
            return
        }

        // Fetch PHAsset using the cached identifier
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [cachedInfo.assetIdentifier],
            options: nil
        )

        guard let foundAsset = fetchResult.firstObject else {
            print("⚠️ [DEVICE-IMAGE] Asset not found (deleted?): \(cachedInfo.assetIdentifier)")
            // Asset was deleted from device - remove from cache
            PendingImageCache.shared.remove(itemId)
            isLoading = false
            return
        }

        // Successfully found asset
        print("✅ [DEVICE-IMAGE] Loaded device photo for itemId: \(itemId)")
        self.asset = foundAsset
        self.mediaType = cachedInfo.mediaType
        isLoading = false
    }
}
