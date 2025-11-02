//
//  CollectionDetailBackgroundAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 2/16/25.
//

import SwiftUI
import Kingfisher

struct CollectionDetailBackgroundAsyncImage: View {
    let urls: PhotoUrls?
    let quality: ImageQuality
    let uploadStatus: UploadStatus?
    let itemId: String?
    let isLivePhoto: Bool
    let isVideo: Bool

    init(urls: PhotoUrls?, quality: ImageQuality, uploadStatus: UploadStatus? = nil, itemId: String? = nil, isLivePhoto: Bool = false, isVideo: Bool = false) {
        self.urls = urls
        self.quality = quality
        self.uploadStatus = uploadStatus
        self.itemId = itemId
        self.isLivePhoto = isLivePhoto
        self.isVideo = isVideo
    }

    var body: some View {
        if uploadStatus == .PENDING {
            // PENDING: Use device photo (no need to pass sizing since background ignores it)
            UnifiedCollectionImageView(
                urls: nil,
                uploadStatus: .PENDING,
                itemId: itemId,
                quality: quality,
                sizing: .aspectFill,
                isLivePhoto: isLivePhoto,
                isVideo: isVideo,
                performanceMode: true
            )
            .ignoresSafeArea()
        } else {
            // Normal: Load from network
            GenericAsyncImage(urls: urls, quality: quality, shouldFixSize: false, performanceMode: true) { image in
                image
                    .contentConfigure { image in
                        image
                            .resizable()
                            .ignoresSafeArea()
                            .scaledToFill()
                    }
            } placeholder: {
                Rectangle()
                    .fill(Color.theme.iconTertiary)
                    .ignoresSafeArea()
            }
        }
    }
}
