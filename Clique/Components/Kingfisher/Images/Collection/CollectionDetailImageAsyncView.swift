//
//  CollectionDetailImageAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI
import Kingfisher
import AVFoundation

struct CollectionDetailImageAsyncView: View {
    let image: CollectionImage
    let quality: ImageQuality
    let forceQuality: Bool
    let isVisible: Bool
    let onRefresh: (() -> Void)?
    let savedPosition: CMTime?
    let onPositionSave: ((CMTime) -> Void)?

    @State private var videoIsVisible: Bool

    init(image: CollectionImage, quality: ImageQuality, forceQuality: Bool = false, isVisible: Bool = true, onRefresh: (() -> Void)? = nil, savedPosition: CMTime? = nil, onPositionSave: ((CMTime) -> Void)? = nil) {
        self.image = image
        self.quality = quality
        self.forceQuality = forceQuality
        self.isVisible = isVisible
        self.onRefresh = onRefresh
        self.savedPosition = savedPosition
        self.onPositionSave = onPositionSave
        self._videoIsVisible = State(initialValue: isVisible)
    }

    var body: some View {
        Group {
            if image.uploadStatus == .PENDING {
                // PENDING: Show device photo
                UnifiedCollectionImageView(
                    urls: nil,
                    uploadStatus: .PENDING,
                    itemId: image.id,
                    quality: quality,
                    sizing: .detailView,
                    isLivePhoto: image.isLivePhoto,
                    isVideo: image.isVideo,
                    performanceMode: false,
                    isVisible: isVisible
                )
            } else if image.isLivePhoto {
                // Live Photo with native-like playback
                // Always use high quality for live photo still images (video quality preference only affects playback)
                NetworkLivePhotoPlayerView(
                    imageUrl: image.imageUrl,
                    videoUrl: image.videoUrls,
                    quality: .high
                )
            } else if image.isVideo {
                // Standalone video with auto-play
                NetworkVideoPlayerView(
                    thumbnailUrl: image.imageUrl,
                    videoUrl: image.videoUrls,
                    quality: quality,
                    forceQuality: forceQuality,
                    isVisible: videoIsVisible,
                    savedPosition: savedPosition,
                    onPositionSave: onPositionSave
                )
            } else {
                // Regular static image
                GenericAsyncImage(urls: image.imageUrl, quality: quality) { image in
                    image
                        .contentConfigure { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                                .clipped()
                        }
                } placeholder: {
                    Rectangle()
                        .fill(.gray)
                        .frameRatio(width: UIScreen.width, ratio: Constants.portraitPostRatio)
                }
            }
        }
        .task(id: isVisible) {
            videoIsVisible = isVisible
        }
    }
}
