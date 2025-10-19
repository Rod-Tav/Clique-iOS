//
//  CollectionBottomCarouselAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI
import Kingfisher

struct CollectionBottomCarouselAsyncView: View {
    let urls: PhotoUrls?
    let width: CGFloat
    let height: CGFloat
    let quality: ImageQuality
    let isLivePhoto: Bool
    let isVideo: Bool

    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality, performanceMode: true) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .roundCorners(8)
        } placeholder: {
            Rectangle()
                .fill(.gray)
                .frame(width: width, height: height)
                .roundCorners(8)
        }
        .overlay(alignment: .topLeading) {
            if isLivePhoto {
                LivePhotoBadge(showText: false)
                    .padding(2)
                    .scaleEffect(0.7)  // Smaller badge for carousel thumbnails
            } else if isVideo {
                VideoBadge(showText: false)
                    .padding(2)
                    .scaleEffect(0.7)  // Smaller badge for carousel thumbnails
            }
        }
    }
}
