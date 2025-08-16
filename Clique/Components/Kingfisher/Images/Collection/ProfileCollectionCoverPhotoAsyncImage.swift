//
//  UserProfileCollectionCoverPhotoAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 2/15/25.
//

import SwiftUI
import Kingfisher

struct ProfileCollectionCoverPhotoAsyncImage: View {
    let urls: PhotoUrls?
    let side: CGFloat
    let quality: ImageQuality
    
    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(side)
                .roundCorners(8)
        } placeholder: {
            ProfileCollectionPlaceholder(side: side)
        }
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
