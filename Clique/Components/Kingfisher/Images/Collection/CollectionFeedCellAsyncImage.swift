//
//  CollectionFeedCellAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/1/25.
//

import SwiftUI
import Kingfisher

struct CollectionFeedCellAsyncImage: View {
    let urls: PhotoUrls?
    let width: CGFloat
    let quality: ImageQuality
    
    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality) { image in
            image
                .contentConfigure { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
        } placeholder: {
            Rectangle()
                .fill(.gray)
                .aspectRatio(1, contentMode: .fill)
                .frame(width)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
