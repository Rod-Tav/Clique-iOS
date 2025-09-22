//
//  LikedFlickNotiAsyncView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/23/25.
//

import SwiftUI

struct LikedFlickNotiAsyncView: View {
    var urls: PhotoUrls?
    let size: CGFloat
    let quality: ImageQuality
    
    var body: some View {
        GenericAsyncImage(urls: urls, quality: quality, performanceMode: true) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(size)
                .roundCorners(8)
        } placeholder: {
            Rectangle()
                .fill(.gray)
                .frame(size)
                .roundCorners(8)
        }
    }
}
