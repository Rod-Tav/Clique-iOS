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
    
    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality, shouldFixSize: false) { image in
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
