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
        GenericAsyncImage(urls: urls, quality: quality, performanceMode: true) { image in
            image
                .contentConfigure { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .format(width)
                }
        } placeholder: {
            Rectangle()
                .fill(.gray)
                .format(width)
        }
    }
}

private extension View {
    func format(_ width: CGFloat) -> some View {
        self
            .aspectRatio(1, contentMode: .fill)
            .frame(width)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
