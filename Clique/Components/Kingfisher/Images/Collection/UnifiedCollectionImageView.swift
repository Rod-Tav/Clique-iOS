//
//  UnifiedCollectionImageView.swift
//  Clique
//
//  Created by Assistant on unified collection image implementation.
//

import SwiftUI
import Kingfisher
import Photos

/// Unified component for loading collection images from either device (PENDING) or network
///
/// Handles two scenarios automatically:
/// - **PENDING uploads**: Loads from device Photos library using AppStorage cache
/// - **Completed uploads**: Loads from network URLs via Kingfisher
///
/// ## Usage
/// ```swift
/// UnifiedCollectionImageView(
///     urls: image.imageUrl,
///     uploadStatus: image.uploadStatus,
///     itemId: image.id,
///     quality: .medium,
///     sizing: .width(UIScreen.width)
/// )
/// ```
struct UnifiedCollectionImageView: View {
    let urls: PhotoUrls?
    var uploadStatus: UploadStatus? = nil
    var itemId: String? = nil
    let quality: ImageQuality
    var sizing: ImageSizing = .aspectFill
    var isLivePhoto: Bool = false
    var isVideo: Bool = false
    var performanceMode: Bool = true

    @State private var deviceAsset: PHAsset?
    @State private var deviceMediaType: MediaType?
    @State private var isLoadingDevice: Bool = false
    @State private var deviceLoadFailed: Bool = false

    var body: some View {
        Group {
            if uploadStatus == .PENDING, let itemId = itemId, !deviceLoadFailed {
                // PENDING: Load from device using AppStorage cache
                deviceImageView
                    .task {
                        await loadDeviceAsset(itemId: itemId)
                    }
            } else {
                // Normal: Load from network (or fallback from failed device load)
                networkImageView
            }
        }
    }

    @ViewBuilder
    private var deviceImageView: some View {
        if let asset = deviceAsset, let mediaType = deviceMediaType {
            // For grid views, always show static thumbnail (even for videos/live photos)
            // For detail/slide views, use appropriate player components
            if isGridView {
                // Grid view: Always use TwoStageImageLoader for static thumbnail
                sizing.applyToView(
                    TwoStageImageLoader(asset: asset, thumbnail: nil, contentMode: sizing.contentMode)
                )
            } else {
                // Detail/slide view: Use appropriate component for each media type
                switch mediaType {
                case .PHOTO:
                    sizing.applyToView(
                        TwoStageImageLoader(asset: asset, thumbnail: nil, contentMode: sizing.contentMode)
                    )
                case .LIVE:
                    sizing.applyToView(
                        LivePhotoPreviewView(asset: asset, thumbnail: nil, contentMode: sizing.contentMode)
                    )
                case .VIDEO:
                    sizing.applyToView(
                        VideoPreviewView(asset: asset, thumbnail: nil, contentMode: sizing.contentMode)
                    )
                }
            }
        } else {
            // Loading or will fallback to network if cache miss
            sizing.applyToView(
                Rectangle()
                    .fill(Color.theme.iconTertiary)
                    .overlay { ProgressView().scaleEffect(0.5) }
            )
        }
    }

    /// Determines if this is a grid view (should show static thumbnails only)
    private var isGridView: Bool {
        switch sizing {
        case .width, .side, .collectionPreview, .custom:
            return true
        case .detailView, .slideView, .aspectFill:
            return false
        }
    }

    @ViewBuilder
    private var networkImageView: some View {
        GenericAsyncImage(
            urls: urls,
            quality: quality,
            shouldFixSize: sizing.shouldFixSize,
            performanceMode: performanceMode
        ) { image in
            image.contentConfigure { img in
                sizing.applyToImage(img)
            }
        } placeholder: {
            sizing.applyToView(
                Rectangle().fill(Color.theme.iconTertiary)
            )
        }
    }

    @MainActor
    private func loadDeviceAsset(itemId: String) async {
        isLoadingDevice = true

        // Check AppStorage cache for asset mapping
        guard let cachedInfo = PendingImageCache.shared.get(itemId) else {
            print("⚠️ [UNIFIED-IMAGE] No cache entry for itemId: \(itemId) - falling back to S3")
            isLoadingDevice = false
            deviceLoadFailed = true
            return
        }

        // Fetch PHAsset from device
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [cachedInfo.assetIdentifier],
            options: nil
        )

        guard let foundAsset = fetchResult.firstObject else {
            print("⚠️ [UNIFIED-IMAGE] Asset not found (deleted?): \(cachedInfo.assetIdentifier) - falling back to S3")
            PendingImageCache.shared.remove(itemId)
            isLoadingDevice = false
            deviceLoadFailed = true
            return
        }

        print("✅ [UNIFIED-IMAGE] Loaded device photo for itemId: \(itemId)")
        self.deviceAsset = foundAsset
        self.deviceMediaType = cachedInfo.mediaType
        isLoadingDevice = false
    }
}

/// Sizing options for collection images
enum ImageSizing {
    case aspectFill
    case collectionPreview  // Special sizing for grid preview (uses Constants.collectionPreviewRatio)
    case detailView  // Special sizing for detail view (uses Constants.portraitPostRatio with .scaledToFit)
    case slideView(CGFloat)  // Special sizing for slide/feed view - preserves natural aspect ratio with width constraint
    case width(CGFloat)  // Grid width with 1:1 aspect ratio
    case side(CGFloat)
    case custom(width: CGFloat?, height: CGFloat?, aspectRatio: CGFloat?, cornerRadius: CGFloat)

    var shouldFixSize: Bool {
        switch self {
        case .aspectFill: return true
        case .collectionPreview: return false
        case .detailView: return false
        case .slideView: return false
        case .width: return true
        case .side: return false
        case .custom: return true
        }
    }

    /// Content mode for device image loaders (TwoStageImageLoader, LivePhotoPreviewView, VideoPreviewView)
    var contentMode: SwiftUI.ContentMode {
        switch self {
        case .detailView, .slideView:
            return .fit  // Detail and slide views should show full image
        default:
            return .fill  // Grid views should fill the frame
        }
    }

    /// Apply sizing to Image views (can use .resizable(), .scaledToFill(), etc.)
    @ViewBuilder
    func applyToImage(_ image: Image) -> some View {
        switch self {
        case .aspectFill:
            image
        case .collectionPreview:
            image
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(minHeight: 0, maxHeight: .infinity)
                .aspectRatio(Constants.collectionPreviewRatio, contentMode: .fill)
                .clipped()
        case .detailView:
            image
                .resizable()
                .scaledToFit()
                .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                .clipped()
        case .slideView(let width):
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: width)
                .roundCorners(8)
        case .width(let width):
            image
                .resizable()
                .scaledToFill()
                .aspectRatio(1, contentMode: .fill)
                .frame(width: width, height: width)
                .clipped()
                .roundCorners(8)
        case .side(let side):
            image
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .roundCorners(8)
        case .custom(let width, let height, let aspectRatio, let cornerRadius):
            image
                .resizable()
                .scaledToFill()
                .if(aspectRatio != nil) { view in
                    view.aspectRatio(aspectRatio!, contentMode: .fill)
                }
                .if(width != nil || height != nil) { view in
                    view.frame(width: width, height: height)
                }
                .if(cornerRadius > 0) { view in
                    view.roundCorners(cornerRadius)
                }
        }
    }

    /// Apply sizing to any View (just frame and clipping, no image-specific modifiers)
    @ViewBuilder
    func applyToView<V: View>(_ view: V) -> some View {
        switch self {
        case .aspectFill:
            view
        case .collectionPreview:
            view
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(minHeight: 0, maxHeight: .infinity)
                .aspectRatio(Constants.collectionPreviewRatio, contentMode: .fill)
                .clipped()
        case .detailView:
            view
                .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                .clipped()
        case .slideView(let width):
            view
                .frame(maxWidth: width)
                .roundCorners(8)
        case .width(let width):
            view
                .aspectRatio(1, contentMode: .fill)
                .frame(width: width, height: width)
                .clipped()
                .roundCorners(8)
        case .side(let side):
            view
                .frame(width: side, height: side)
                .roundCorners(8)
        case .custom(let width, let height, let aspectRatio, let cornerRadius):
            view
                .if(aspectRatio != nil) { v in
                    v.aspectRatio(aspectRatio!, contentMode: .fill)
                }
                .if(width != nil || height != nil) { v in
                    v.frame(width: width, height: height)
                }
                .if(cornerRadius > 0) { v in
                    v.roundCorners(cornerRadius)
                }
        }
    }
}
