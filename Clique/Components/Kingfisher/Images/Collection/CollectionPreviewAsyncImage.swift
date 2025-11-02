//
//  CollectionPreviewAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI
import Kingfisher

/// Grid preview image for collections - thin wrapper around UnifiedCollectionImageView
struct CollectionPreviewAsyncImage: View {
    let urls: PhotoUrls?
    let quality: ImageQuality
    let isLivePhoto: Bool
    let isVideo: Bool
    let uploadStatus: UploadStatus?
    let itemId: String?
    let onRefresh: (() -> Void)?

    init(urls: PhotoUrls?, quality: ImageQuality, isLivePhoto: Bool, isVideo: Bool, uploadStatus: UploadStatus? = nil, itemId: String? = nil, onRefresh: (() -> Void)? = nil) {
        self.urls = urls
        self.quality = quality
        self.isLivePhoto = isLivePhoto
        self.isVideo = isVideo
        self.uploadStatus = uploadStatus
        self.itemId = itemId
        self.onRefresh = onRefresh
    }

    var body: some View {
        UnifiedCollectionImageView(
            urls: urls,
            uploadStatus: uploadStatus,
            itemId: itemId,
            quality: quality,
            sizing: .collectionPreview,
            isLivePhoto: isLivePhoto,
            isVideo: isVideo,
            performanceMode: true
        )
    }
}
