//
//  CollapsedBannerAsyncImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/10/25.
//

import SwiftUI
import Kingfisher

struct CollapsedBannerAsyncImage: View {
    let banner: PhotoUrls?
    let quality: ImageQuality
    
    var body: some View {
        GenericAsyncImage(urls: banner, quality: quality) { image in
            image
                .contentConfigure { $0.collapsedBannerModifiers() }
        } placeholder: {
            CollapsedBannerPlaceholder()
        }
    }
}

struct CollapsedBannerPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.theme.iconTertiary)
            .frame(width: UIScreen.width, height: UIScreen.width / Constants.collapsedBannerRatio)
    }
}
