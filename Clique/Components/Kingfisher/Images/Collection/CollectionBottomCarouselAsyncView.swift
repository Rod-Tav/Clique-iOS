//
//  CollectionBottomCarouselAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI
import Kingfisher

struct CollectionBottomCarouselAsyncView: View {
    let urls: PhotoUrls?
    let width: CGFloat
    let height: CGFloat
    let quality: ImageQuality
    
    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .roundCorners(8)
        } placeholder: {
            Rectangle()
                .fill(.gray)
                .frame(width: width, height: height)
                .roundCorners(8)
        }
    }
}
