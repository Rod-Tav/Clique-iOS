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
    var uploadStatus: UploadStatus? = nil
    var itemId: String? = nil
    var onRefresh: (() -> Void)? = nil

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
