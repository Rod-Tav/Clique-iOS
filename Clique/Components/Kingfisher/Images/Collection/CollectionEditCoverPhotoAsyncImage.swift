//
//  CollectionCoverPhoto.swift
//  Clique
//
//  Created by Quinn Liu on 3/20/25.
//

import SwiftUI

struct CollectionEditCoverPhotoAsyncImage: View {
    let urls: PhotoUrls?
    let quality: ImageQuality

    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality) { image in
            image
                .contentConfigure { image in
                    image
                        .collectionCoverPreviewModifiers()
                }
        } placeholder: {
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray)
                .frameRatio(width: UIScreen.width - 32, ratio: Constants.collectionCoverPreviewRatio)
        }
    }
}
