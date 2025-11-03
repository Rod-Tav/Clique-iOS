//
//  UserProfileCollectionCoverPhotoAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI
import Kingfisher

/// Profile collection cover photo - thin wrapper around UnifiedCollectionImageView
struct ProfileCollectionCoverPhotoAsyncImage: View {
    let urls: PhotoUrls?
    let side: CGFloat
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
            sizing: .side(side),
            performanceMode: true
        )
    }
}

struct ProfileCollectionPlaceholder: View {
    let side: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(Color.theme.iconTertiary)
            .frame(side)
            .roundCorners(8)
    }
}
