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
    var uploadStatus: UploadStatus? = nil
    var itemId: String? = nil
    var isLivePhoto: Bool = false
    var isVideo: Bool = false

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
