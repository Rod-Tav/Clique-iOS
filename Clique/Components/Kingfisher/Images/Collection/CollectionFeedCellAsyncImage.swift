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
    let uploadStatus: UploadStatus? = nil
    let itemId: String? = nil
    let onRefresh: (() -> Void)? = nil

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
