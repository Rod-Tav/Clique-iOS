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
    let uploadStatus: UploadStatus?
    let itemId: String?
    let isLivePhoto: Bool
    let isVideo: Bool

    init(urls: PhotoUrls?, width: CGFloat, height: CGFloat, quality: ImageQuality, uploadStatus: UploadStatus? = nil, itemId: String? = nil, isLivePhoto: Bool = false, isVideo: Bool = false) {
        self.urls = urls
        self.width = width
        self.height = height
        self.quality = quality
        self.uploadStatus = uploadStatus
        self.itemId = itemId
        self.isLivePhoto = isLivePhoto
        self.isVideo = isVideo
    }

    var body: some View {
        Group {
            if uploadStatus == .PENDING {
                // PENDING: Use device photo
                UnifiedCollectionImageView(
                    urls: nil,
                    uploadStatus: .PENDING,
                    itemId: itemId,
                    quality: quality,
                    sizing: .custom(width: width, height: height, aspectRatio: nil, cornerRadius: 8),
                    isLivePhoto: isLivePhoto,
                    isVideo: isVideo,
                    performanceMode: true
                )
            } else {
                // Normal: Load from network
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
            }
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
