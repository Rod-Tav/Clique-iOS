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

    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality, shouldFixSize: false) { image in
            image
                .contentConfigure { image in
                    image
                        .collectionPreviewImageModifiers()
                }
        } placeholder: {
            Rectangle()
                .fill(.gray)
        }
    }
}
