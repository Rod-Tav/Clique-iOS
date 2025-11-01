//
//  CollectionDetailImageAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI
import Kingfisher

struct CollectionDetailImageAsyncView: View {
    let image: CollectionImage
    let quality: ImageQuality
    let forceQuality: Bool
    let isVisible: Bool

    init(image: CollectionImage, quality: ImageQuality, forceQuality: Bool = false, isVisible: Bool = true) {
        self.image = image
        self.quality = quality
        self.forceQuality = forceQuality
        self.isVisible = isVisible
    }

    var body: some View {
        if image.isLivePhoto {
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
                isVisible: isVisible
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
}
