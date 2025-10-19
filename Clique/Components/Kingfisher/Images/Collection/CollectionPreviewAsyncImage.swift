//
//  CollectionPreviewAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI
import Kingfisher

struct CollectionPreviewAsyncImage: View {
    let urls: PhotoUrls?
    let quality: ImageQuality
    let isLivePhoto: Bool
    let isVideo: Bool

    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality, shouldFixSize: false, performanceMode: true) { image in
            image
                .contentConfigure { image in
                    image
                        .collectionPreviewImageModifiers()
                }
        } placeholder: {
            Rectangle()
                .fill(.gray)
        }
        .overlay(alignment: .topLeading) {
            if isLivePhoto {
                LivePhotoBadge()
                    .padding(4)
            } else if isVideo {
                VideoBadge()
                    .padding(4)
            }
        }
    }
}
