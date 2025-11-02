//
//  CollectionFeedCellAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/1/25.
//

import SwiftUI
import Kingfisher

/// Feed cell image for collections - thin wrapper around UnifiedCollectionImageView
struct CollectionFeedCellAsyncImage: View {
    let urls: PhotoUrls?
    let width: CGFloat
    let quality: ImageQuality
    let uploadStatus: UploadStatus?
    let itemId: String?
    let onRefresh: (() -> Void)?

    init(urls: PhotoUrls?, width: CGFloat, quality: ImageQuality, uploadStatus: UploadStatus? = nil, itemId: String? = nil, onRefresh: (() -> Void)? = nil) {
        self.urls = urls
        self.width = width
        self.quality = quality
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
            sizing: .width(width),
            performanceMode: true
        )
    }
}
