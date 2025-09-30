//
//  LivePhotoAsyncView.swift
//  Clique
//
//  Created by Assistant on Phase 4 implementation.
//

import SwiftUI
import PhotosUI
import Kingfisher

/// Displays Live Photos using Kingfisher's PHLivePhotoView support, with fallback to static images.
///
/// This component intelligently handles both Live Photos and regular photos:
/// - For Live Photos: Uses Kingfisher to load and cache PHLivePhoto with playback
/// - For regular photos: Standard image loading via GenericAsyncImage
///
/// ## Live Photo Loading
/// Leverages Kingfisher's `PHLivePhotoView.kf.setImage(with: [imageURL, videoURL])`
/// to automatically download, cache, and display Live Photos.
///
/// ## Architecture
/// - Uses UIViewRepresentable to wrap PHLivePhotoView
/// - Kingfisher handles caching of both image and video components
/// - Automatic playback on tap (standard iOS behavior)
/// - Disk cache for Live Photo data
///
/// ## Performance
/// - Cached Live Photos load instantly from disk
/// - Network fetching for first load
/// - Same cache infrastructure as images
struct LivePhotoAsyncView: View {
    /// The collection image to display (may be photo or Live Photo)
    let collectionImage: CollectionImage
    /// Image quality to load
    let quality: ImageQuality
    /// Optional content mode
    var contentMode: ContentMode = .fill
    /// Optional frame size
    var frameSize: CGSize? = nil
    /// Whether to use performance mode (no progressive loading)
    var performanceMode: Bool = false

    var body: some View {
        if collectionImage.isLivePhoto,
           let imageUrl = collectionImage.imageUrl?.url(for: quality),
           let videoUrl = collectionImage.videoUrls?.bestUrl {
            // Use PHLivePhotoView for Live Photos
            LivePhotoViewRepresentable(
                imageURL: imageUrl,
                videoURL: videoUrl,
                contentMode: contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
            )
            .if(frameSize != nil) { view in
                view.frame(width: frameSize!.width, height: frameSize!.height)
            }
            .overlay(alignment: .topLeading) {
                livePhotoBadge
            }
        } else if let imageUrl = collectionImage.imageUrl {
            // Standard image for regular photos
            GenericAsyncImage(
                urls: imageUrl,
                quality: quality,
                performanceMode: performanceMode
            )
            .aspectRatio(contentMode: contentMode)
            .if(frameSize != nil) { view in
                view.frame(width: frameSize!.width, height: frameSize!.height)
            }
        }
    }

    /// Live Photo badge indicator
    private var livePhotoBadge: some View {
        Image(systemName: "livephoto")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .padding(8)
    }
}

/// UIViewRepresentable wrapper for PHLivePhotoView with Kingfisher loading
struct LivePhotoViewRepresentable: UIViewRepresentable {
    let imageURL: URL
    let videoURL: URL
    var contentMode: UIView.ContentMode = .scaleAspectFill

    func makeUIView(context: Context) -> PHLivePhotoView {
        let livePhotoView = PHLivePhotoView()
        livePhotoView.contentMode = contentMode
        return livePhotoView
    }

    func updateUIView(_ livePhotoView: PHLivePhotoView, context: Context) {
        // Load Live Photo using Kingfisher
        let urls = [imageURL, videoURL]

        livePhotoView.kf.setImage(with: urls, options: [
            .transition(.fade(0.2)),
            .cacheOriginalImage, // Cache the Live Photo data
            .diskCacheExpiration(.days(7)) // Keep in cache for 7 days
        ]) { result in
            switch result {
            case .success(let retrieveResult):
                print("✅ Live Photo loaded: \(retrieveResult.livePhoto != nil)")
                print("📦 Cache type: \(retrieveResult.loadingInfo.cacheType)")
            case .failure(let error):
                print("❌ Live Photo loading error: \(error)")
            }
        }
    }
}

/// Lightweight Live Photo view for grid displays (no video playback)
/// Shows still image with Live Photo badge overlay
struct LivePhotoGridView: View {
    let collectionImage: CollectionImage
    let quality: ImageQuality

    var body: some View {
        ZStack {
            if let imageUrl = collectionImage.imageUrl {
                GenericAsyncImage(
                    urls: imageUrl,
                    quality: quality,
                    performanceMode: true // Always use performance mode in grids
                )
                .aspectRatio(contentMode: .fill)
            }

            // Live Photo badge (bottom-left)
            if collectionImage.isLivePhoto {
                VStack {
                    Spacer()

                    HStack {
                        Image(systemName: "livephoto")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .padding(6)

                        Spacer()
                    }
                }
            }
        }
    }
}