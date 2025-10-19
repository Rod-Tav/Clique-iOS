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

    var body: some View {
        if image.isLivePhoto {
            // Live Photo with native-like playback
            NetworkLivePhotoPlayerView(
                imageUrl: image.imageUrl,
                videoUrl: image.videoUrls,
                quality: quality
            )
            .overlay(alignment: .topLeading) {
                LivePhotoBadge()
                    .padding(8)
            }
        } else if image.isVideo {
            // Standalone video with auto-play
            NetworkVideoPlayerView(
                thumbnailUrl: image.imageUrl,
                videoUrl: image.videoUrls,
                quality: quality
            )
            .overlay(alignment: .topLeading) {
                VideoBadge()
                    .padding(8)
            }
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
